"""Compile and publish a package or executable using an isolated Linux SDK."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import uuid
from linux_package_artifacts import bundle, digest, publish


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--sdk', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--kind', choices=['package', 'program'], required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--package-path', type=Path, action='append', default=[])
    parser.add_argument('--unit-path', type=Path, action='append', default=[])
    parser.add_argument('--require', action='append', default=[])
    parser.add_argument('--smart', action='store_true')
    args = parser.parse_args()
    sdk, source, output = args.sdk.resolve(), args.source.resolve(), args.output.resolve()
    manifest = json.loads((sdk / 'sdk.json').read_text())
    if manifest['format'] != 2 or manifest['target'] != 'x86_64-linux-gnu':
        raise ValueError('Unsupported package SDK')
    for artifact in manifest['artifacts']:
        path = (sdk / artifact['path']).resolve()
        if not path.is_relative_to(sdk) or digest(path) != artifact['sha256']:
            raise ValueError('SDK artifact differs: ' + artifact['path'])
    directories = [bundle(sdk / 'packages'), *[bundle(p) for p in args.package_path]]
    output.mkdir(parents=True, exist_ok=True)
    work = output / ('work-' + uuid.uuid4().hex)
    work.mkdir()
    compiler = sdk / 'bin/ppcx64'
    command = [str(compiler), '-n', '-Mobjfpc', '-Cg', '-Fj' + manifest['sdk_identity'],
               '-Fk' + uuid.uuid4().hex, '-Fu' + str(sdk / 'units'), '-FU' + str(work), '-FE' + str(work),
               '-k-rpath', '-k$ORIGIN', '-k-z', '-korigin']
    for directory in directories:
        # -k text is assembled into the linker's command line by FPC; retain
        # quoting there as well as in this subprocess argument list.
        if '"' in str(directory):
            raise ValueError('Package directory cannot contain a double quote')
        command += ['-Fp' + str(directory), '-Fl' + str(directory), '-k-rpath-link', '-k"' + str(directory) + '"']
    for directory in [source.parent, *args.unit_path]:
        command.append('-Fu' + str(directory.resolve()))
    if args.smart:
        command += ['-CX', '-XX']
    if args.kind == 'program':
        # PIC accesses plus PIE avoid executable COPY relocations of package data.
        command += ['-k-pie', '-k-z', '-knocopyreloc', '-k-z', '-ktext', '-k-z', '-krelro', '-k-z', '-know']
        for package in dict.fromkeys(['nxrtl', *args.require]):
            if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_.]*', package):
                raise ValueError('Invalid package name')
            command.append('-FP' + package)
    command.append(str(source))
    log = work / 'compile.log'
    with log.open('w') as stream:
        result = subprocess.run(command, cwd=work, stdout=stream, stderr=subprocess.STDOUT, timeout=600)
    (work / 'build.json').write_text(json.dumps(dict(command=command, exit_code=result.returncode), indent=2))
    if result.returncode:
        raise RuntimeError(f'Compilation failed ({result.returncode}): {log}\n' + log.read_text()[-4000:])
    generation = publish(output, work, source.stem, args.kind, manifest['sdk_identity'], directories)
    print('Built', args.kind, source.stem, 'Bundle:', generation, flush=True)


if __name__ == '__main__':
    main()
