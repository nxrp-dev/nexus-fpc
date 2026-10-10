"""Sequential unified threadvar regressions on a matching Windows or Linux SDK."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--sdk', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    fixtures = root / 'tests/dynamic-packages'
    sdk, out = args.sdk.resolve(), args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise ValueError('Output directory must be empty')
    source, packages, host = [out / p for p in ('source', 'packages', 'host')]
    for p in (source, packages, host):
        p.mkdir()
    windows = os.name == 'nt'
    steps = []

    def run(name, command, cwd=out):
        log = out / (name + '.log')
        with log.open('w') as stream:
            result = subprocess.run(list(map(str, command)), cwd=cwd,
                                    stdout=stream, stderr=subprocess.STDOUT, timeout=300)
        steps.append(dict(name=name, exit_code=result.returncode, log=str(log)))
        (out / 'steps.json').write_text(json.dumps(steps, indent=2))
        if result.returncode:
            raise RuntimeError(f'{name}: exit {result.returncode}: {log}\n{log.read_text(errors="replace")[-4000:]}')
        print('PASS', name, flush=True)

    def compile(name, path, required=(), program=False):
        if windows:
            def quote(value):
                return "'" + str(value).replace("'", "''") + "'"
            script = out / (name + '.ps1')
            expression = ('& ' + quote(root / 'scripts/Invoke-NexusFPCPackageCompile.ps1') +
                          ' -SdkRoot ' + quote(sdk) + ' -Source ' + quote(path) +
                          ' -Kind ' + ('Console' if program else 'Package') +
                          ' -OutputDirectory ' + quote(host if program else packages) +
                          ' -PackagePath ' + quote(packages))
            if required:
                expression += ' -RequiredPackages @(' + ','.join(map(quote, required)) + ')'
            script.write_text("$ErrorActionPreference='Stop'\ntry {\n" + expression +
                              "\n} catch { Write-Output $_.Exception.Message; exit 1 }\n")
            command = ['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass',
                       '-File', script]
        else:
            command = [sys.executable, sdk / 'bin/compile_linux_package.py', '--sdk', sdk,
                       '--source', path, '--kind', 'program' if program else 'package',
                       '--output', host if program else packages, '--package-path', packages]
            for requirement in required:
                command += ['--require', requirement]
        run(name, command)

    shutil.copy2(fixtures / 'threadvar_contracts.pas', source)
    declaration = source / 'tvcontracts.ppk'
    declaration.write_text('package tvcontracts; requires nxrtl; contains Threadvar_Contracts; end.\n')
    compile('contracts', declaration)
    template = (fixtures / 'threadvar_provider.pas.in').read_text()
    for index in range(26):
        name = 'tv' + str(index)
        unit = 'Threadvar_Provider_' + str(index)
        (source / (unit.lower() + '.pas')).write_text(template.replace('@INDEX@', str(index)))
        contents = unit
        if index == 25:
            name = 'tvfail'
            contents += ', Threadvar_Failure'
            (source / 'threadvar_failure.pas').write_text(
                "unit Threadvar_Failure; {$mode objfpc} interface implementation "
                "uses SysUtils, Threadvar_Provider_25; threadvar Value: LongInt; "
                "initialization if Value<>0 then Halt(91); Value:=18; "
                "raise Exception.Create('threadvar-init-failure'); end.\n")
        declaration = source / (name + '.ppk')
        declaration.write_text(f'package {name}; requires nxrtl, tvcontracts; contains {contents}; end.\n')
        compile(name, declaration)
    compile('host', fixtures / 'threadvar_package_host.pas', ('tvcontracts', 'tv24'), True)

    def selected(directory):
        data = json.loads((directory / 'current.json').read_text(encoding='utf-8-sig'))
        return directory / data.get('Generation', data.get('generation'))

    distribution = selected(host)
    for p in selected(packages).iterdir():
        if p.suffix.lower() in ('.dll', '.so'):
            shutil.copy2(p, distribution)
    executable = distribution / ('threadvar_package_host.exe' if windows else 'threadvar_package_host')
    run('runtime', [executable], distribution)
    assert 'PASS unified package threadvars' in (out / 'runtime.log').read_text()


if __name__ == '__main__':
    main()
