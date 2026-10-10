"""Sequential before/after static-build timings using two fully bootstrapped trees."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import shutil
import statistics
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--baseline-root', type=Path, required=True)
    parser.add_argument('--candidate-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--samples', type=int, default=7)
    parser.add_argument('--compiler-samples', type=int, default=3)
    args = parser.parse_args()
    if args.samples < 3 or not 3 <= args.compiler_samples <= args.samples:
        parser.error('Use at least three compiler samples, no more than total samples')
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    roots = dict(baseline=args.baseline_root.resolve(), candidate=args.candidate_root.resolve())
    windows = platform.system() == 'Windows'
    suffix, target = ('.exe', 'x86_64-win64') if windows else ('', 'x86_64-linux')
    fixture = Path(__file__).resolve().parent / 'benchmarks'
    source = out / 'source'
    shutil.copytree(fixture, source)
    report = dict(platform=platform.platform(), samples=args.samples,
                  compiler_samples=args.compiler_samples, configurations={}, measurements=[])
    options = {}
    executables = {}
    for name, root in roots.items():
        compiler = root / ('compiler/ppcx64' + suffix)
        rtl = root / 'rtl/units' / target
        case = out / name
        case.mkdir()
        options[name] = [str(compiler), '-n', '-O2', '-B', '-Fu' + str(rtl),
                         '-FU' + str(case), '-FE' + str(case)]
        executables[name] = case / ('package_bench' + suffix)
        report['configurations'][name] = dict(root=str(root), compiler_sha256=hashlib.sha256(
            compiler.read_bytes()).hexdigest(), system_ppu_sha256=hashlib.sha256(
            (rtl / 'system.ppu').read_bytes()).hexdigest())

    def run(name, command, record=True):
        start = time.perf_counter()
        process = subprocess.run(list(map(str, command)), cwd=out, stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, timeout=600)
        elapsed = time.perf_counter() - start
        output = process.stdout.decode(errors='replace')
        (out / (name + '.log')).write_text(output)
        if process.returncode:
            raise RuntimeError(f'{name} failed: {output[-3000:]}')
        if record:
            report['measurements'].append(dict(name=name, seconds=elapsed, command=list(map(str, command))))
            (out / 'timings.json').write_text(json.dumps(report, indent=2))
        return elapsed, output.strip()

    # Warm each compiler and the source cache before collecting measurements.
    for name in roots:
        run(name + '-warm-build', [*options[name], source / 'package_bench.pas'], False)
    expected = {}
    workloads = dict(globals=200_000_000, managed=2_000_000)
    for name, executable in executables.items():
        for workload, count in workloads.items():
            _, checksum = run(name + '-warm-' + workload, [executable, workload, count], False)
            if workload in expected and expected[workload] != checksum:
                raise RuntimeError('Before/after runtime checksums differ')
            expected[workload] = checksum

    # Alternate order, run no builds concurrently, and preserve all raw samples.
    for sample in range(args.samples):
        names = list(roots) if sample % 2 == 0 else list(reversed(roots))
        for name in names:
            run(f'{name}-fixture-build-{sample}', [*options[name], source / 'package_bench.pas'])
            for workload, count in workloads.items():
                _, checksum = run(f'{name}-{workload}-{sample}', [executables[name], workload, count])
                if checksum != expected[workload]:
                    raise RuntimeError('Runtime checksum changed')
            # Compile identical compiler sources with each compiler and matched RTL.
            # -B forces source compilation into private outputs, leaving both trees alone.
            if sample >= args.compiler_samples:
                continue
            compiler_source = roots['candidate'] / 'compiler'
            build = out / name / ('compiler-' + str(sample))
            build.mkdir()
            command = [*options[name][:-2], '-dx86_64', '-FU' + str(build), '-FE' + str(build)]
            for part in ('', 'x86_64', 'x86', 'systems'):
                command += ['-Fu' + str(compiler_source / part), '-Fi' + str(compiler_source / part)]
            run(f'{name}-compiler-build-{sample}', [*command, compiler_source / 'pp.pas'])
            run(f'{name}-compiler-version-{sample}', [build / ('pp' + suffix), '-iV'], False)
        print('PASS timing sample', sample + 1, flush=True)

    summary = {}
    for workload in ('fixture-build', 'compiler-build', 'globals', 'managed'):
        summary[workload] = {}
        for name in roots:
            values = [m['seconds'] for m in report['measurements']
                      if m['name'].startswith(name + '-' + workload + '-')]
            summary[workload][name] = dict(median=statistics.median(values), minimum=min(values), maximum=max(values))
        summary[workload]['percent_change'] = 100 * (
            summary[workload]['candidate']['median'] / summary[workload]['baseline']['median'] - 1)
    report['summary'] = summary
    report['checksums'] = expected
    report['executable_bytes'] = {name: path.stat().st_size for name, path in executables.items()}
    (out / 'timings.json').write_text(json.dumps(report, indent=2))
    print(json.dumps(summary, indent=2), flush=True)


if __name__ == '__main__':
    main()
