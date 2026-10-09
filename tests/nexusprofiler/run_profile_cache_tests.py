"""Sequential Win64 profiler runtime loading and PPU cache regressions."""

import argparse
import hashlib
import json
from pathlib import Path
import re
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
    out = (args.output_root or Path(tempfile.mkdtemp(prefix='nx-profile-cache-'))).resolve()
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise RuntimeError('Output directory must be empty')
    print('Results:', out, flush=True)
    compiler = args.compiler.resolve()
    source = root / 'packages/nexusprofiler/src'
    fixtures = root / 'packages/nexusprofiler/tests'
    readobj = shutil.which('llvm-readobj.exe')
    if not readobj:
        raise RuntimeError('LLVM tools must be on PATH')
    steps = []

    def run(name, command, cwd=root, expected=0, text=None):
        command = [str(x) for x in command]
        log = out / (name + '.log')
        with log.open('w') as stream:
            result = subprocess.run(command, cwd=cwd, stdout=stream,
                                    stderr=subprocess.STDOUT, timeout=120)
        output = log.read_text(errors='replace')
        steps.append(dict(name=name, command=command, cwd=str(cwd), exit_code=result.returncode,
                          expected=expected, log=str(log)))
        (out / 'steps.json').write_text(json.dumps(steps, indent=2))
        if result.returncode != expected or (text and text.lower() not in output.lower()):
            raise RuntimeError(f'{name}: exit {result.returncode}, expected {expected}; details: {log}')
        if 'Internal error' in output:
            raise RuntimeError(f'{name}: internal compiler error; details: {log}')
        print('PASS', name, flush=True)
        return output

    common = [compiler, '-n', '-Fu' + str(args.rtl.resolve()), '-Aas-clang', '-XLL']

    def outputs(directory):
        directory.mkdir(parents=True, exist_ok=True)
        return ['-FU' + str(directory), '-FE' + str(directory)]

    def hashes(directory, unit):
        return [hashlib.sha256((directory / (unit + ext)).read_bytes()).hexdigest()
                for ext in ('.ppu', '.o')]

    # This reader stays unprofiled and separate from every tested cache.
    probe = out / 'probe'
    run('probe-build', common + outputs(probe) + ['-O2', '-Fu' + str(source),
                                                fixtures / 'nxprofile_trace_probe.pas'])

    def smoke(name, executable, expected_calls=8):
        execution = out / (name + '-execution')
        execution.mkdir()
        run(name, [executable], cwd=execution)
        traces = list(execution.glob('nexus-profile-*.nxp'))
        assert len(traces) == 1, f'{name}: expected one trace'
        output = run(name + '-trace', [probe / 'nxprofile_trace_probe.exe', traces[0]])
        values = {key: int(value) for key, value in re.findall(r'^([a-z_]+)=(\d+)$', output, re.MULTILINE)}
        for key, expected in dict(calls=expected_calls, unmatched=0, lost=0, trace_end=1, truncated=0).items():
            assert values.get(key) == expected, (name, key, values)
        if expected_calls == 8:
            assert values['normal_returns'] == 7 and values['unwinds'] == 1, (name, values)

    for smart in (False, True):
        mode = 'smart' if smart else 'normal'
        opts = ['-XX'] if smart else []
        case = out / mode
        runtime = case / 'runtime'
        cache = case / 'cache'
        run(mode + '-runtime-build', common + outputs(runtime) +
            ['-Fu' + str(source), '-B', '-O2', '-profile', source / 'NXProfilerRuntime.pas'])
        run(mode + '-mixed-probe', common + outputs(cache) +
            ['-Fu' + str(source), '-O2', fixtures / 'nxprofile_trace_probe.pas'])
        mixed = common + outputs(cache) + ['-Fu' + str(source), '-Fu' + str(runtime),
            '-Fu' + str(fixtures), '-O-', '-g', '-gl', '-gw3', *opts]
        # No -B: reproduce the invalidated compiler-injected runtime PPU.
        run(mode + '-mixed-build', mixed + ['-profile', fixtures / 'profiler_smoke.pas'])
        smoke(mode + '-mixed-run', cache / 'profiler_smoke.exe')
        before = hashes(cache, 'profiler_smoke_unit')
        runtime_before = hashes(cache, 'NXProfilerRuntime')
        run(mode + '-cached-build', mixed + ['-profile', fixtures / 'profiler_smoke.pas'])
        assert before == hashes(cache, 'profiler_smoke_unit'), 'valid profiled PPU was rebuilt'
        assert runtime_before == hashes(cache, 'NXProfilerRuntime'), 'valid runtime PPU was rebuilt'
        smoke(mode + '-cached-run', cache / 'profiler_smoke.exe')

        run(mode + '-ordinary-build', mixed + [fixtures / 'profiler_smoke.pas'])
        dump = run(mode + '-ordinary-object', [readobj, '--symbols', '--sections', cache / 'profiler_smoke_unit.o'])
        assert 'nxp_enter' not in dump and '.nxprof' not in dump, 'ordinary unit retained profiling'
        dump = run(mode + '-ordinary-exe', [readobj, '--symbols', '--sections', '--coff-imports', cache / 'profiler_smoke.exe'])
        assert not re.search(r'\.nxprof|nxp_|__NXP_specific_handler', dump), 'ordinary EXE retained profiling'
        run(mode + '-ordinary-run', [cache / 'profiler_smoke.exe'], cwd=cache)
        assert not list(cache.glob('nexus-profile-*.nxp')), 'ordinary EXE wrote a trace'
        before = hashes(cache, 'profiler_smoke_unit')
        run(mode + '-gapped-build', mixed + ['-profile', fixtures / 'profiler_smoke.pas'])
        assert before == hashes(cache, 'profiler_smoke_unit'), 'profiling rebuilt deliberately unprofiled unit'
        run(mode + '-forced-build', mixed + ['-profile', '-B', fixtures / 'profiler_smoke.pas'])
        dump = run(mode + '-forced-object', [readobj, '--symbols', cache / 'profiler_smoke_unit.o'])
        assert 'nxp_enter' in dump, 'forced profile build omitted instrumentation'
        smoke(mode + '-forced-run', cache / 'profiler_smoke.exe')

    # No uses clause and no runtime PPU: the implicit dependency must still be
    # compiled before parsing program declarations and generating profiler hooks.
    fresh = out / 'source-only'
    fresh_opts = outputs(fresh)
    program = fresh / 'implicit_profile.pas'
    program.write_text('program implicit_profile; begin nxp_flush; end.\n')
    run('source-only-build', common + fresh_opts + ['-Fu' + str(source), '-profile', program])
    execution = out / 'source-only-execution'
    execution.mkdir()
    run('source-only-run', [fresh / 'implicit_profile.exe'], cwd=execution)
    assert len(list(execution.glob('nexus-profile-*.nxp'))) == 1

    missing = out / 'missing-runtime'
    missing_opts = outputs(missing)
    program = missing / 'missing_profile.pas'
    program.write_text('program missing_profile; begin end.\n')
    run('missing-runtime', common + missing_opts + ['-profile', program], expected=1,
        text="Can't find unit NXProfilerRuntime")

    # An invalidated runtime PPU without its source must diagnose the missing
    # rebuild input, rather than entering the synchronous-loader internal error.
    stale = out / 'stale-runtime'
    local_source = stale / 'source'
    local_source.mkdir(parents=True)
    for name in ('NXProfilerRuntime.pas', 'NXProfile.pas'):
        shutil.copy2(source / name, local_source)
    runtime = stale / 'runtime'
    cache = stale / 'cache'
    run('stale-runtime-build', common + outputs(runtime) + ['-Fu' + str(local_source),
        '-B', '-O2', '-profile', local_source / 'NXProfilerRuntime.pas'])
    dependency = local_source / 'NXProfile.pas'
    original = dependency.read_text()
    changed = original.replace('\nconst\n', '\nconst\n  ProfileCacheChanged = 1;\n', 1)
    assert original != changed, 'cannot locate dependency constants'
    dependency.write_text(changed)
    run('stale-probe-build', common + outputs(cache) + ['-Fu' + str(local_source), '-O2',
        fixtures / 'nxprofile_trace_probe.pas'])
    (local_source / 'NXProfilerRuntime.pas').rename(local_source / 'NXProfilerRuntime.pas.hidden')
    diagnostic = run('stale-runtime-no-source', common + outputs(cache) + ['-Fu' + str(local_source),
        '-Fu' + str(runtime), '-Fu' + str(fixtures), '-O-', '-g', '-gl', '-gw3', '-profile',
        fixtures / 'profiler_smoke.pas'], expected=1, text="Can't find unit NXProfilerRuntime")
    assert 'checksum changed' in diagnostic and 'NXProfilerRuntime.pas not found' in diagnostic
    print(f'PASS {len(steps)} profiler cache steps. Results: {out}')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, AssertionError) as error:
        raise SystemExit(str(error))
