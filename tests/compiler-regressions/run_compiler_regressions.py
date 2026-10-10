"""Sequential generic-set and CORBA conversion regressions, including saved PPUs."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--compiler', type=Path, default=root / 'compiler/ppcx64.exe')
    parser.add_argument('--rtl', type=Path, default=root / 'rtl/units/x86_64-win64')
    parser.add_argument('--output-root', type=Path)
    args = parser.parse_args()
    compiler = args.compiler.resolve()
    rtl = args.rtl.resolve()
    out = (args.output_root or Path(tempfile.mkdtemp(prefix='nx-compiler-regressions-'))).resolve()
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise RuntimeError('Output directory must be empty')
    print('Results:', out, flush=True)
    results = []
    common = [str(compiler), '-n', '-Fu' + str(rtl), '-vw', '-Criot']
    suffix = '.exe' if compiler.suffix.lower() == '.exe' else ''

    def run(name, command, directory, expected=0, diagnostic=None):
        command = [str(arg) for arg in command]
        result = subprocess.run(command, cwd=directory, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                errors='replace', timeout=120)
        log = out / (name + '.log')
        log.write_text(result.stdout, encoding='utf-8')
        passed = result.returncode == expected
        if diagnostic:
            passed = passed and diagnostic in result.stdout
        passed = passed and not any(marker in result.stdout.lower() for marker in
                                    ('internal error', 'exception internally', 'eaccessviolation'))
        results.append(dict(name=name, passed=passed, command=command,
                            exit_code=result.returncode, expected=expected, log=str(log)))
        (out / 'results.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
        if not passed:
            raise RuntimeError(f'{name}: exit {result.returncode}; expected {expected}. See {log}')
        print('PASS', name, flush=True)

    def check(name, fixture, options=(), diagnostic=None, execute=True):
        directory = out / name
        directory.mkdir()
        source = directory / fixture.name
        shutil.copy2(fixture, source)
        run(name + '-compile', common + ['-Fi' + str(root / 'tests/tbs'),
            '-FU' + str(directory), '-FE' + str(directory), *options, source],
            directory, expected=1 if diagnostic else 0, diagnostic=diagnostic)
        if execute and not diagnostic:
            run(name + '-run', [directory / (source.stem + suffix)], directory)
        return directory

    for name, fixture, options in (
        ('generic-delphi', 'tw40453.pp', ()),
        ('generic-objfpc', 'tb_generic_set_operations_objfpc.pp', ()),
        ('literals-delphi', 'tb_generic_set_literals_delphi.pp', ()),
        ('literals-objfpc', 'tb_generic_set_literals_objfpc.pp', ()),
        ('literals-optimized', 'tb_generic_set_literals_delphi.pp', ('-O2',)),
        ('corba-strings', 'tw6036a.pp', ()),
        ('corba-strings-optimized', 'tw6036a.pp', ('-O2',)),
        ('corba-short-default', 'tb_corba_string_ids_short.pp', ()),
    ):
        check(name, root / 'tests/tbs' / fixture, options)

    for fixture, diagnostic in (
        ('tb_generic_set_invalid_object.pp', 'Illegal type declaration of set elements'),
        ('tb_generic_set_invalid_range.pp', 'Illegal type declaration of set elements'),
        ('tb_generic_set_literal_object.pp', 'Ordinal expression expected'),
        ('tb_generic_set_literal_string.pp', 'Ordinal expression expected'),
        ('tb_corba_id_invalid_integer.pp', 'Incompatible types'),
        *((f'tb0215{letter}.pp', 'Error:') for letter in 'abcde'),
    ):
        check(Path(fixture).stem, root / 'tests/tbf' / fixture, diagnostic=diagnostic)
    check('tw6036b', root / 'tests/webtbf/tw6036b.pp', diagnostic='Incompatible types')

    # Compile a unit in its own invocation, then hide its only available source.
    # Neither consumer can find the repository's unit source via -Fu.
    unit = check('saved-unit', root / 'tests/tbs/ugeneric_set_storage.pp', execute=False)
    (unit / 'ugeneric_set_storage.pp').rename(unit / 'ugeneric_set_storage.pp.saved')
    def unit_hashes():
        # A unit containing only generic declarations need not emit an object.
        return {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                for path in unit.iterdir() if path.suffix in ('.ppu', '.o')}

    if not (unit / 'ugeneric_set_storage.ppu').is_file():
        raise RuntimeError('The generic unit did not produce a PPU')
    hashes = unit_hashes()
    for name in ('saved-unit-consumer', 'cached-unit-consumer'):
        check(name, root / 'tests/tbs/tb_generic_set_storage.pp', ['-Fu' + str(unit)])
        if hashes != unit_hashes():
            raise RuntimeError('The saved generic unit was unexpectedly rebuilt')
    print(f'All {len(results)} compile/run checks passed.', flush=True)


if __name__ == '__main__':
    main()
