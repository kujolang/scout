"""Compare an immutable Scout ref with the checkout; timings are evidence, not CI gates.

Usage: python3 tests/scripts/benchmark_hardening.py KUJO_BIN BASE_REF OUTPUT_JSON
"""
import json
import hashlib
import pathlib
import platform
import resource
import shutil
import statistics
import subprocess
import sys
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[2]
KUJO = str(pathlib.Path(sys.argv[1]).resolve())
REF = sys.argv[2]
DEST = pathlib.Path(sys.argv[3]).resolve()
FILES = ['scout.kujo', 'config.json', *[str(p.relative_to(ROOT)) for p in (ROOT / 'lib').glob('*.kujo')]]
report = {'baseline_ref': REF, 'runtime': subprocess.check_output([KUJO, '--version'], text=True).strip(),
          'runtime_binary_sha256': hashlib.sha256(pathlib.Path(KUJO).read_bytes()).hexdigest(),
          'platform': platform.platform(),
          'samples_per_case': 3, 'cases': {}}
with tempfile.TemporaryDirectory(prefix='scout-benchmark-') as work:
    work = pathlib.Path(work)
    target = work / 'project'
    target.mkdir()
    # A real source scan: unique imports and routes deliberately reverse ordered.
    (target / 'app.js').write_text('\n'.join(
        f'import m{i} from "module-{i:03}";\napp.get("/route-{i:03}", handler);'
        for i in reversed(range(64))) + '\n')
    normalized = {}
    normalized_docs = {}
    sort_outputs = {}
    for version in ('before', 'after'):
        code = work / version
        code.mkdir()
        for name in FILES:
            output = code / name
            output.parent.mkdir(parents=True, exist_ok=True)
            if version == 'before':
                output.write_bytes(subprocess.check_output(['git', 'show', f'{REF}:{name}'], cwd=ROOT))
            else:
                shutil.copyfile(ROOT / name, output)
        shutil.copyfile(ROOT / 'tests/fixtures/hardening/sorting.kujo', code / 'sorting.kujo')
        for case in ('sort512', 'scan-full', 'scan-minimal'):
            samples = []
            for sample in range(3):
                output = code / f'{case}-{sample}'
                command = [KUJO, 'run', 'sorting.kujo'] if case == 'sort512' else [
                    KUJO, 'run', 'scout.kujo', str(target), '-o', str(output),
                    '--output-profile', case.removeprefix('scan-')]
                start = time.perf_counter()
                cpu_start = resource.getrusage(resource.RUSAGE_CHILDREN)
                result = subprocess.run(command, cwd=code, capture_output=True, text=True, check=True, timeout=120)
                elapsed = round(time.perf_counter() - start, 6)
                cpu_end = resource.getrusage(resource.RUSAGE_CHILDREN)
                receipt = {'wall_seconds': elapsed, 'stdout_bytes': len(result.stdout.encode()),
                           'cpu_seconds': round(cpu_end.ru_utime + cpu_end.ru_stime -
                                                cpu_start.ru_utime - cpu_start.ru_stime, 6),
                           'stdout_lines': len(result.stdout.splitlines())}
                if case == 'sort512':
                    data = json.loads(result.stdout)
                    receipt['sort_ms'] = data['elapsed_ms']
                    sort_outputs[version] = data['items']
                else:
                    folder = next(output.iterdir())
                    receipt['artifact_bytes'] = sum(p.stat().st_size for p in folder.iterdir() if p.is_file())
                    receipt['llms_bytes'] = (folder / 'llms.txt').stat().st_size
                    data = json.loads((folder / 'intelligence.json').read_text())
                    for field in ('run_timestamp', 'output', 'output_root'):
                        data.pop(field)
                    key = (version, case)
                    if key in normalized:
                        assert normalized[key] == data, 'repeated scan changed behavior'
                    normalized[key] = data
                    normalized_docs[key] = {p.name: p.read_text() for p in folder.iterdir()
                                             if p.suffix == '.md' or p.name == 'llms.txt'}
                samples.append(receipt)
            report['cases'][f'{version}-{case}'] = {'samples': samples,
                'median_cpu_seconds': statistics.median(s['cpu_seconds'] for s in samples),
                'median_wall_seconds': statistics.median(s['wall_seconds'] for s in samples)}
    assert sort_outputs['before'] == sort_outputs['after'], 'sorting behavior changed'
    for case in ('scan-full', 'scan-minimal'):
        assert normalized['before', case] == normalized['after', case], 'scan behavior changed'
        assert normalized_docs['before', case] == normalized_docs['after', case], 'context documents changed'
report['equivalence'] = 'exact sorting and context documents match; normalized intelligence matches across versions and repeated scans'
DEST.parent.mkdir(parents=True, exist_ok=True)
DEST.write_text(json.dumps(report, indent=2) + '\n')
print(f'Benchmark and equivalence checks passed: {DEST}')
