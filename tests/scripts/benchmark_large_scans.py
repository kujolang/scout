#!/usr/bin/env python3
"""Deterministic Scout workload generator and observational resource benchmark."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import subprocess
import tempfile
import time


def generate(root: Path, fast: bool):
    sizes = (32, 4, 8, 1) if fast else (1024, 32, 64, 32)
    file_count, heavy_files, routes_per_file, large_mib = sizes
    cases = {}
    many = root / "many-files"
    many.mkdir()
    for number in range(file_count):
        (many / f"unit_{number:04d}.py").write_text(
            f"import many_{number}\n@app.get('/many/{number}')\n", encoding="utf-8"
        )
    cases["many_files"] = (many, file_count, file_count, file_count, 0)

    heavy = root / "route-heavy"
    heavy.mkdir()
    for number in range(heavy_files):
        lines = []
        for route in range(routes_per_file):
            lines += [f"import heavy_{number}_{route}",
                      f"@app.post('/heavy/{number}/{route}')"]
        (heavy / f"routes_{number:03d}.py").write_text(
            "\n".join(lines) + "\n", encoding="utf-8"
        )
    total_routes = heavy_files * routes_per_file
    cases["route_heavy"] = (heavy, heavy_files, total_routes, total_routes, 0)

    large = root / "large-source"
    large.mkdir()
    for number in range(2):
        with (large / f"large_{number}.py").open("w", encoding="utf-8") as stream:
            stream.write(f"import large_{number}\n")
            for _ in range(large_mib):
                stream.write("z" * 1_048_576)
    cases["large_source"] = (large, 2, 2, 0, 2)
    return cases


def fingerprint(root: Path):
    digest = hashlib.sha256()
    for path in sorted(root.iterdir()):
        digest.update(path.name.encode("utf-8"))
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1_048_576), b""):
                digest.update(chunk)
    return digest.hexdigest()


def run_case(runtime: Path, entry: Path, output: Path, name: str, case):
    source, expected_files, expected_deps, expected_routes, expected_diagnostics = case
    output.mkdir()
    args = [str(runtime), "run", str(entry), "--", str(source), "-o", str(output),
            "-d", "2", "--skip-security", "--quick"]
    stdout_path = output.parent / f"{name}.stdout"
    stderr_path = output.parent / f"{name}.stderr"
    started = time.perf_counter()
    with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
        process = subprocess.Popen(args, cwd=entry.parent, stdout=stdout, stderr=stderr)
        _, status, usage = os.wait4(process.pid, 0)
    elapsed = time.perf_counter() - started
    code = os.waitstatus_to_exitcode(status)
    if code:
        raise RuntimeError(f"{name}: Scout exited {code}: {stderr_path.read_text()}")
    reports = list(output.glob("*/scan_manifest.json"))
    if len(reports) != 1:
        raise AssertionError(f"{name}: expected one published report, found {len(reports)}")
    report = reports[0].parent
    intelligence = json.loads((report / "intelligence.json").read_text())
    actual = (intelligence["metrics"]["total_files"], len(intelligence["dependencies"]),
              len(intelligence["routes"]), len(intelligence["parse_errors"]))
    expected = (expected_files, expected_deps, expected_routes, expected_diagnostics)
    if actual != expected:
        raise AssertionError(f"{name}: expected {expected}, got {actual}")
    peak_bytes = usage.ru_maxrss if os.uname().sysname == "Darwin" else usage.ru_maxrss * 1024
    return {
        "fixture_sha256": fingerprint(source),
        "source_files": expected_files,
        "source_bytes": sum(path.stat().st_size for path in source.iterdir()),
        "dependencies": actual[1], "routes": actual[2],
        "diagnostics": actual[3], "elapsed_seconds": round(elapsed, 3),
        "child_cpu_seconds": round(usage.ru_utime + usage.ru_stime, 3),
        "peak_rss_bytes": peak_bytes,
        "report_bytes": sum(path.stat().st_size for path in report.rglob("*") if path.is_file()),
        "artifact_count": sum(path.is_file() for path in report.rglob("*")),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kujo", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--fast", action="store_true")
    args = parser.parse_args()
    runtime = args.kujo.resolve(strict=True)
    entry = Path(__file__).resolve().parents[2] / "scout.kujo"
    with tempfile.TemporaryDirectory(prefix="scout-large-benchmark-") as temporary:
        root = Path(temporary)
        fixture_root = root / "fixtures"
        fixture_root.mkdir()
        workloads = generate(fixture_root, args.fast)
        results = {name: run_case(runtime, entry, root / f"out-{name}", name, case)
                   for name, case in workloads.items()}
    payload = {"tool": "scout-large-benchmark-v1", "runtime_version":
               subprocess.check_output([str(runtime), "--version"], text=True).strip(),
               "mode": "fast" if args.fast else "full", "host": os.uname().sysname,
               "measurements": results,
               "note": "Observational child-process measurements; no CI speed thresholds."}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    print(f"Validated {len(results)} deterministic workloads: {args.output}")


if __name__ == "__main__":
    main()
