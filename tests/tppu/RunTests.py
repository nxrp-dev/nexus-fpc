#!/usr/bin/env python3
"""Run the compiler recompilation suite in its own output directory (Linux)."""
# Copyright (c) 2026 Kevin Collins.
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
import argparse
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['program', 'compiler', 'rtl', 'runtime-units']:
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    if os.name == 'nt':
        parser.error('This fixture preparation currently requires Linux.')
    program = args.program.resolve()
    compiler = args.compiler.resolve()
    rtl = args.rtl.resolve()
    runtime_units = args.runtime_units.resolve()
    for path in [program, compiler, rtl, runtime_units]:
        if not path.exists():
            parser.error('Missing prerequisite: ' + str(path))
    if not any((runtime_units / ('variants' + suffix)).exists() for suffix in ['.nxu', '.ppu']):
        parser.error('Build RTLObjPasTests first to supply matching precompiled Variants.')
    output = program.parent
    source = Path(__file__).resolve().parent
    for child in source.iterdir():
        if child.is_dir() and child.name != '__pycache__':
            shutil.copytree(child, output / child.name, dirs_exist_ok=True,
                            ignore=shutil.ignore_patterns('ppus', '*.o', '*.nxu', '*.ppu'))
    wrapper = output / 'RunCompiler'
    wrapper.write_text('#!' + sys.executable + '\nimport os,sys\n'
                       + 'compiler=' + repr(str(compiler)) + '\n'
                       + "flags=['-Aas-clang','-XLL','-vi']\n"
                       + "if '-n' not in sys.argv[1:]: flags += "
                       + repr(['-n', '-Fu' + str(rtl), '-Fu' + str(runtime_units)]) + '\n'
                       + 'os.execv(compiler,[compiler]+flags+sys.argv[1:])\n')
    wrapper.chmod(0o755)
    process = subprocess.Popen([str(program)], cwd=output, start_new_session=True,
                               env=dict(os.environ, TEST_FPC=str(wrapper)))
    try:
        return process.wait(timeout=180)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
        return 124
    finally:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass


if __name__ == '__main__':
    sys.exit(main())
