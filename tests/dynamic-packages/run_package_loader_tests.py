"""Real Win64 LoadPackage/UnloadPackage, failure ownership and bundle publication."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile


def quote(value):
    return "'" + str(value).replace("'", "''") + "'"


def selected(directory):
    return directory / json.loads((directory / 'current.json').read_text(encoding='utf-8-sig'))['Generation']


def descriptor_offsets(data):
    pe = struct.unpack_from('<I', data, 0x3c)[0]
    count, opt_size = struct.unpack_from('<H', data, pe+6)[0], struct.unpack_from('<H', data, pe+20)[0]
    opt = pe+24
    assert struct.unpack_from('<H', data, opt)[0] == 0x20b
    base = struct.unpack_from('<Q', data, opt+24)[0]
    sections = [struct.unpack_from('<IIII', data, opt+opt_size+40*i+8) for i in range(count)]

    def offset(rva):
        for virtual_size, address, size, raw in sections:
            if address <= rva < address+max(virtual_size, size):
                return raw+rva-address
        raise AssertionError(f'Unmapped RVA {rva:x}')

    export = offset(struct.unpack_from('<I', data, opt+112)[0])
    names = struct.unpack_from('<I', data, export+24)[0]
    functions, name_table, ordinals = [offset(struct.unpack_from('<I', data, export+n)[0]) for n in (28,32,36)]
    for i in range(names):
        name_offset = offset(struct.unpack_from('<I', data, name_table+i*4)[0])
        name = data[name_offset:data.index(0, name_offset)].decode()
        if name == 'FPC_PACKAGE_INFO':
            ordinal = struct.unpack_from('<H', data, ordinals+i*2)[0]
            pointer = offset(struct.unpack_from('<I', data, functions+ordinal*4)[0])
            descriptor = offset(struct.unpack_from('<Q', data, pointer)[0]-base)
            sdk = offset(struct.unpack_from('<Q', data, descriptor+18*8)[0]-base)
            build = offset(struct.unpack_from('<Q', data, descriptor+19*8)[0]-base)
            return descriptor, sdk, build
    raise AssertionError('Missing stable package descriptor export')


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--sdk-root', type=Path)
    parser.add_argument('--output-root', type=Path)
    parser.add_argument('--smart', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    out = (args.output_root or Path(tempfile.mkdtemp(prefix='nxpkg-loader-'))).resolve()
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()): raise RuntimeError('Output root must be empty')
    steps = []
    print('Output:', out, flush=True)

    def record(name, **details):
        steps.append(dict(name=name, **details))
        (out / 'steps.json').write_text(json.dumps(steps, indent=2))
        print('PASS', name, flush=True)

    def run(name, command, expected=0, text=None, cwd=out):
        log = out / (name+'.log')
        with log.open('w') as stream:
            p = subprocess.run([str(x) for x in command], cwd=cwd, stdout=stream, stderr=subprocess.STDOUT, timeout=900)
        output = log.read_text(errors='replace')
        if p.returncode != expected or (text and text not in output):
            raise RuntimeError(f'{name}: exit {p.returncode}; details: {log}')
        record(name, exit_code=p.returncode, command=[str(x) for x in command], log=str(log))
        return output

    def ps(name, code, expected=0, text=None):
        script = out / (name+'.ps1')
        script.write_text("$ErrorActionPreference='Stop'\ntry {\n"+code+"\n} catch { Write-Output $_.Exception.Message; exit 1 }\n")
        return run(name, ['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-File',script], expected, text)

    smart = ' -SmartLink' if args.smart else ''
    sdk = args.sdk_root.resolve() if args.sdk_root else out/'sdk'
    if not args.sdk_root:
        ps('sdk', '& '+quote(root/'scripts/Build-NexusFPCPackageSDK.ps1')+' -OutputRoot '+quote(sdk)+' -RunExamples'+smart)
    late = out/'late'
    ps('late-examples', '& '+quote(root/'scripts/Build-NexusFPCLatePackageExamples.ps1')+
       ' -SdkRoot '+quote(sdk)+' -OutputRoot '+quote(late)+' -RunExamples'+smart)
    providers = selected(late/'packages')
    for kind in ('console','gui'):
        image = selected(late/('late_'+kind))/('late_'+kind+'.exe')
        imports = run(kind+'-imports', ['llvm-readobj.exe','--coff-imports',image])
        assert 'pluginleft.dll' not in imports.lower() and 'pluginbase.dll' not in imports.lower()
        assert 'democontracts.dll' in imports.lower()
        record(kind+'-genuinely-late')
        relocated = out/('runtime only '+kind)
        relocated.mkdir()
        for file in image.parent.iterdir():
            if file.suffix in ('.exe','.dll'): shutil.copy2(file,relocated)
        result_log = relocated/'result.log'
        run(kind+'-relocated', [relocated/image.name, result_log], cwd=relocated)
        assert result_log.read_text().splitlines()==['PASS late '+kind,'CBLRlrbBLlb']
        record(kind+'-relocated-lifecycle')
        for mismatch in ('abi','sdk','dependency'):
            rejected = out/('startup-'+kind+'-'+mismatch)
            rejected.mkdir()
            for file in image.parent.iterdir():
                if file.suffix in ('.exe','.dll'): shutil.copy2(file,rejected)
            target = rejected/'democontracts.dll'
            data = bytearray(target.read_bytes())
            descriptor,sdk_offset,build_offset = descriptor_offsets(data)
            if mismatch=='abi': struct.pack_into('<Q',data,descriptor+8,999)
            else:
                offset = sdk_offset if mismatch=='sdk' else build_offset
                data[offset+1:offset+1+data[offset]] = b'E'*data[offset]
            target.write_bytes(data)
            result_log = rejected/'result.log'
            run('startup-'+kind+'-'+mismatch,[rejected/image.name,result_log],expected=217,
                text='Package startup failed: EPackageError:',cwd=rejected)
            assert not result_log.exists()

    fixtures = out/'fixtures'
    fixtures.mkdir()
    distribution = out/'negative-packages'
    distribution.mkdir()
    compiler = root/'scripts/Invoke-NexusFPCPackageCompile.ps1'

    def compile_code(name, source, kind='Package', required=None, expected=0, text=None):
        destination = distribution if kind == 'Package' else out/name
        expression = '& '+quote(compiler)+' -SdkRoot '+quote(sdk)+' -Kind '+kind+' -Source '+quote(source)+\
            ' -OutputDirectory '+quote(destination)+' -PackagePath @('+quote(providers)+','+quote(distribution)+')'+smart
        if required: expression += ' -RequiredPackages '+required
        return ps('build-'+name, expression, expected, text)

    def package(name, units, requires='nxrtl, democontracts'):
        directory = fixtures/name
        directory.mkdir()
        for unit, content in units.items():
            (directory/(unit+'.pas')).write_text(content)
        source = directory/(name+'.ppk')
        source.write_text('package '+name+'; requires '+requires+'; contains '+','.join(units)+'; end.\n')
        compile_code(name, source)

    def unit(name, declarations='', initialization='', finalization='', interface=''):
        return f'''unit {name}; {{$mode objfpc}}{{$H+}}
interface
uses SysUtils, Classes, PkgContracts;
{interface}
implementation
{declarations}
initialization
{initialization}
finalization
{finalization}
end.
'''

    error_class = '''type ELocalFailure = class(Exception)
  destructor Destroy; override;
end;
destructor ELocalFailure.Destroy;
begin Trace:=Trace+'D'; inherited Destroy; end;
'''
    package('failinit', {
        'FailFirst': unit('FailFirst', initialization="Trace:=Trace+'F';", finalization="Trace:=Trace+'f';"),
        'FailLast': unit('FailLast', error_class+'type TFailedClass = class(TPersistent);',
                        "Trace:=Trace+'!'; RegisterClassAlias(TFailedClass,'FailedAlias'); raise ELocalFailure.Create('init-marker');")})
    package('faildependency', {'FailDependencyUnit': unit('FailDependencyUnit',error_class,
        "Trace:=Trace+'!'; raise ELocalFailure.Create('init-marker');")},
        'nxrtl, democontracts, pluginbase')
    package('cleanupfail', {
        'CleanupFirst': unit('CleanupFirst', initialization="Trace:=Trace+'X';",
                             finalization="Trace:=Trace+'x'; raise Exception.Create('cleanup-marker');"),
        'CleanupLast': unit('CleanupLast', error_class,
                           "Trace:=Trace+'!'; raise ELocalFailure.Create('init-marker');")},
        'nxrtl, democontracts, pluginbase')
    package('failfini', {'FailFiniUnit': unit('FailFiniUnit', error_class,
                                            "Trace:=Trace+'Z';", "Trace:=Trace+'z'; raise ELocalFailure.Create('finalization-marker');")})
    package('callbackfail', {'CallbackFailUnit': unit('CallbackFailUnit',error_class+
        "procedure FailedCleanup; begin Trace:=Trace+'K'; raise ELocalFailure.Create('callback-marker'); end;",
        "Trace:=Trace+'Y'; RegisterPackageCleanup(PackageModuleFromAddress(@FailedCleanup),@FailedCleanup);",
        "Trace:=Trace+'y';")})
    package('newtls', {'NewTLSUnit': unit('NewTLSUnit', 'threadvar Value: LongInt;', "if Value<>0 then raise Exception.Create('TLS not zero'); Value:=42; Trace:=Trace+'T';",
        "if Value<>42 then raise Exception.Create('TLS lost before finalization'); Trace:=Trace+'t';")})
    package('nestedload', {'NestedLoadUnit': unit('NestedLoadUnit', initialization="Trace:=Trace+'Q'; LoadPackage('pluginleft.dll');")})
    package('nestedunload', {'NestedUnloadUnit': unit('NestedUnloadUnit', 'procedure Marker; begin end;',
         "Trace:=Trace+'U';", "Trace:=Trace+'u'; UnloadPackage(PackageModuleFromAddress(@Marker));")})
    package('nonexception', {'NonExceptionUnit': unit('NonExceptionUnit',
         "type TLocalError = class(TObject) destructor Destroy; override; end;\n"
         "destructor TLocalError.Destroy; begin Trace:=Trace+'D'; inherited Destroy; end;",
         "Trace:=Trace+'N'; raise TLocalError.Create;")})
    compile_code('failure-host', root/'tests/dynamic-packages/package_loader_failures.pas', 'Console', 'democontracts')
    app = selected(out/'failure-host')

    for mode in ('init','new-dependency','live-dependency','cleanup','finalization','callback','tls','nested-load','nested-unload','non-exception','missing','not-package','duplicate','sdk','abi','dependency'):
        case = out/('case-'+mode)
        case.mkdir()
        for file in app.iterdir():
            if file.suffix in ('.dll','.exe'): shutil.copy2(file,case)
        if mode == 'duplicate': shutil.copy2(case/'pluginleft.dll',case/'duplicate.dll')
        if mode in ('sdk','abi','dependency'):
            target = case/('pluginbase.dll' if mode=='dependency' else 'bad.dll')
            if mode != 'dependency': shutil.copy2(case/'pluginleft.dll',target)
            data = bytearray(target.read_bytes())
            descriptor,sdk_offset,build_offset = descriptor_offsets(data)
            if mode=='abi': struct.pack_into('<Q',data,descriptor+8,999)
            elif mode=='sdk': data[sdk_offset+1:sdk_offset+1+data[sdk_offset]] = b'F'*data[sdk_offset]
            else: data[build_offset+1:build_offset+1+data[build_offset]] = b'E'*data[build_offset]
            target.write_bytes(data)
        command = [case/'package_loader_failures.exe',mode]
        if mode == 'not-package': command += [Path(r'C:\Windows\System32\version.dll')]
        run('run-'+mode,command,text='PASS '+mode)

    # Failed compiler/linker invocations and incoherent dependency updates must
    # preserve the previously selected, complete generation byte for byte.
    current = distribution/'current.json'
    before = current.read_bytes()
    original = {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in selected(distribution).iterdir()}
    broken = fixtures/'broken.ppk'
    broken.write_text('package broken; requires nxrtl; contains MissingUnit; end.\n')
    compile_code('broken',broken,expected=1,text='Compilation failed')
    assert current.read_bytes()==before
    assert original=={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in selected(distribution).iterdir()}
    record('failed-build-preserves-publication')
    link_unit = fixtures/'BrokenLinkUnit.pas'
    link_unit.write_text(unit('BrokenLinkUnit',
        "procedure MissingExternal; external name 'MissingPackageLinkSymbol';", 'MissingExternal;'))
    broken.write_text('package broken; requires nxrtl, democontracts; contains BrokenLinkUnit; end.\n')
    compile_code('broken-link',broken,expected=1,text='Compilation failed')
    def compiler_log(path):
        data = path.read_bytes()
        return data.decode('utf-16' if data.startswith(b'\xff\xfe') else 'utf-8', errors='replace')
    assert any('MissingPackageLinkSymbol' in compiler_log(p) for p in distribution.glob('work-*/compile.log'))
    assert current.read_bytes()==before
    assert original=={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in selected(distribution).iterdir()}
    record('failed-link-preserves-publication')
    # A rebuilt provider cannot replace an owner while old consumers remain.
    compile_code('stale-consumers',late/'source/base/pluginbase.ppk',expected=1,text='Dependency build mismatch')
    assert current.read_bytes()==before
    record('stale-consumers-preserve-publication')
    mismatched = out/'mismatched-pair'
    mismatched.mkdir()
    for file in selected(distribution).iterdir():
        if file.suffix in ('.pcp','.dll'): shutil.copy2(file,mismatched)
    data = bytearray((mismatched/'failinit.dll').read_bytes())
    _,_,build_offset = descriptor_offsets(data)
    data[build_offset+1:build_offset+1+data[build_offset]] = b'E'*data[build_offset]
    (mismatched/'failinit.dll').write_bytes(data)
    pair_output = out/'pair-output'
    pair_output.mkdir()
    ps('reject-mismatched-pair', '. '+quote(root/'scripts/NexusFPCPackageArtifacts.ps1')+
       '\nPublish-NexusPackageBundle -OutputDirectory '+quote(pair_output)+' -Work '+quote(mismatched)+
       " -Name failinit -Kind Package -SDKIdentity "+quote(json.loads((sdk/'sdk.json').read_text(encoding='utf-8-sig'))['SDKIdentity'])+
       ' -PackageDirectories '+quote(mismatched),expected=1,text='metadata/image identity mismatch')
    assert not (pair_output/'current.json').exists()
    # Copy an unrelated dependency build over its manifest-protected artifact.
    damaged = out/'damaged-bundle'
    shutil.copytree(distribution,damaged)
    dll = selected(damaged)/'failinit.dll'
    dll.write_bytes(dll.read_bytes()+b'tampered')
    ps('reject-damaged-bundle', '. '+quote(root/'scripts/NexusFPCPackageArtifacts.ps1')+
       '\nGet-NexusPackageBundle '+quote(damaged),expected=1,text='differs from its manifest')
    print(f'PASS {len(steps)} loader checks. Logs: {out}',flush=True)


if __name__=='__main__': main()
