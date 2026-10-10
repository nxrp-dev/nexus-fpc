"""Build an isolated experimental x86-64 glibc package SDK on Linux."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import uuid


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--source-root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output-root', type=Path, required=True)
    parser.add_argument('--bootstrap', default='fpc')
    parser.add_argument('--bootstrap-rtl', type=Path)
    parser.add_argument('--smart', action='store_true')
    parser.add_argument('--resume', action='store_true', help='Resume an unfinished build; completed SDKs are immutable.')
    args = parser.parse_args()
    if platform.system() != 'Linux' or platform.machine() != 'x86_64':
        raise SystemExit('Requires x86-64 Linux; from Windows run this script in WSL.')
    libc = subprocess.check_output(['getconf', 'GNU_LIBC_VERSION'], text=True).strip()
    if not libc.startswith('glibc '):
        raise SystemExit('This package SDK requires glibc. musl is unsupported.')
    root, out = args.source_root.resolve(), args.output_root.resolve()
    if any(character.isspace() for path in (root, out) for character in str(path)):
        raise SystemExit('FPC RTL makefiles require source and SDK build paths without whitespace. Relocated SDKs may use spaces.')
    if out.exists() and any(out.iterdir()) and (not args.resume or (out / 'sdk.json').exists()):
        raise SystemExit('Output root must be new or empty.')
    for tool in (args.bootstrap, 'make', 'as', 'ld', 'gcc', 'readelf', 'fpcres'):
        if not shutil.which(tool):
            raise SystemExit('Missing build prerequisite: ' + tool)
    bootstrap = str(Path(shutil.which(args.bootstrap)).resolve())
    version = subprocess.check_output([bootstrap, '-iV'], text=True).strip()
    bootstrap_rtl = args.bootstrap_rtl
    if bootstrap_rtl is None:
        candidates = [Path('/usr/lib/x86_64-linux-gnu/fpc') / version / 'units/x86_64-linux/rtl',
                      Path(bootstrap).parent / 'units/x86_64-linux/rtl']
        bootstrap_rtl = next((p for p in candidates if (p / 'system.ppu').is_file()), None)
    if bootstrap_rtl is None or not (bootstrap_rtl / 'system.ppu').is_file():
        raise SystemExit('Specify --bootstrap-rtl containing the bootstrap System PPU.')
    work, binary, packages, units, logs = [out / p for p in ('work', 'bin', 'packages', 'units', 'logs')]
    source, compiler_units, rtl, rtl_bin, foundation = [work / p for p in (
        'compiler-source', 'compiler-units', 'rtl-units', 'rtl-bin', 'nxrtl')]
    for p in (work, binary, packages, units, logs, source, compiler_units, rtl, rtl_bin, foundation):
        p.mkdir(parents=True, exist_ok=True)
    steps = []
    environment = os.environ.copy()
    # WSL inherits Windows tools. FPCMake searches for pwd.exe before pwd,
    # which otherwise misidentifies this native Linux build as a Windows host.
    environment['PATH'] = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

    def run(name, command, cwd=work):
        command = list(map(str, command))
        log = logs / (name + '.log')
        with log.open('w') as stream:
            result = subprocess.run(command, cwd=cwd, env=environment,
                                    stdout=stream, stderr=subprocess.STDOUT, timeout=2400)
        steps.append(dict(name=name, command=command, exit_code=result.returncode, log=str(log)))
        (logs / 'steps.json').write_text(json.dumps(steps, indent=2))
        if result.returncode:
            raise RuntimeError(f'{name} failed ({result.returncode}): {log}\n' + log.read_text()[-6000:])
        print('PASS', name, flush=True)

    for original in (root / 'compiler').rglob('*'):
        if not original.is_file() or original.suffix not in ('.pp', '.pas', '.inc'):
            continue
        if original.name in ('msgtxt.inc', 'msgidx.inc'):
            continue
        target = source / original.relative_to(root / 'compiler')
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(original, target)
    base = ['-n', '-Fu' + str(bootstrap_rtl), '-FU' + str(compiler_units)]
    run('message-generator', [bootstrap, *base, '-FE' + str(work), source / 'utils/msg2inc.pp'])
    run('messages', [work / 'msg2inc', root / 'compiler/msg/errore.msg', source / 'msg', 'msg'])
    options = [*base, '-O2', '-dx86_64', '-Fu' + str(compiler_units), '-FE' + str(binary)]
    for part in ('', 'x86_64', 'x86', 'systems'):
        options += ['-Fu' + str(source / part), '-Fi' + str(source / part)]
    run('compiler', [bootstrap, *options, '-oppcx64', source / 'pp.pas'])
    compiler = binary / 'ppcx64'
    # All RTL artifacts are private to this SDK; -Cg applies to every provider unit.
    run('matching-rtl', ['make', '-s', '-B', '-C', root / 'rtl/linux', 'all', f'FPC={compiler}',
        'CPU_TARGET=x86_64', 'OS_TARGET=linux', f'COMPILER_UNITTARGETDIR={rtl}',
        f'COMPILER_TARGETDIR={rtl_bin}', f'FPCMADE={work}/rtl.fpcmade', 'OPT=-n -Cg'])
    identity = hashlib.sha256()
    identity.update((digest(compiler) + str(args.smart) + libc).encode())
    for p in sorted((root / 'rtl').rglob('*')):
        if p.is_file() and p.suffix in ('.pp', '.pas', '.inc'):
            identity.update((p.relative_to(root).as_posix() + ':' + digest(p)).encode())
    sdk_id = identity.hexdigest().upper()
    if args.resume:
        # A compiler code-generation fix need not change a PPU checksum. Rebuild
        # the foundation's own units when resuming an unfinished SDK.
        for directory in (foundation, units):
            for artifact in directory.iterdir():
                if artifact.is_file() and artifact.suffix in ('.ppu', '.o', '.a'):
                    artifact.unlink()
    shutil.copy2(root / 'rtl/linux/nxrtl.ppk', foundation)
    common = ['-n', '-Mobjfpc', '-Cg', '-Fj' + sdk_id, '-Fk' + uuid.uuid4().hex, '-Fu' + str(rtl)]
    if args.smart:
        common += ['-CX', '-XX']
    run('shared-rtl', [compiler, *common, '-Fu' + str(root / 'rtl/inc'), '-FU' + str(foundation),
        '-FE' + str(foundation), '-k-rpath', '-k$ORIGIN', foundation / 'nxrtl.ppk'])
    for name in ('nxrtl.pcp', 'libnxrtl.so'):
        shutil.copy2(foundation / name, packages)
    shutil.copy2(rtl / 'abitag.o', units)
    shutil.copy2(root / 'rtl/linux/sysinitpkg.pp', work)
    run('host-startup', [compiler, '-n', '-Mobjfpc', '-Cg', '-Fu' + str(units), '-Fp' + str(packages),
        '-Fl' + str(packages), '-FPnxrtl', '-Fj' + sdk_id, '-FU' + str(units),
        '-Fi' + str(root / 'rtl/linux'), '-Fi' + str(root / 'rtl/linux/x86_64'),
        work / 'sysinitpkg.pp'])
    for name in ('compile_linux_package.py', 'linux_package_artifacts.py'):
        path = root / 'scripts' / name
        if path.is_file():
            shutil.copy2(path, binary)
    artifacts = [dict(path=p.relative_to(out).as_posix(), sha256=digest(p))
                 for d in (binary, packages, units) for p in sorted(d.iterdir()) if p.is_file()]
    (out / 'sdk.json').write_text(json.dumps(dict(format=2, target='x86_64-linux-gnu',
        experimental=True, foundation='nxrtl', compiler_version=subprocess.check_output([compiler, '-iV'], text=True).strip(),
        smart=args.smart, sdk_identity=sdk_id, build_libc=libc, artifacts=artifacts), indent=2))
    print('Package SDK ready:', out, flush=True)


if __name__ == '__main__':
    main()
