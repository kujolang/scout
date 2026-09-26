#!/usr/bin/env python3
"""Profile Scout's route accumulation, sorting, and report-assembly hotspot."""

import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]

def run(command, cwd=ROOT):
    started = time.perf_counter()
    result = subprocess.run(command, cwd=cwd, check=True, text=True, capture_output=True)
    return time.perf_counter() - started, result.stdout

def scan(runtime, source, output, quick):
    command = [str(runtime), "run", str(ROOT / "scout.kujo"), "--", str(source),
               "-o", str(output), "-d", "2", "--skip-deps", "--skip-security", "--strict"]
    if quick:
        command.append("--quick")
    elapsed, _ = run(command)
    reports = list(output.glob("*/intelligence.json"))
    if len(reports) != 1:
        raise RuntimeError(f"expected one report, found {len(reports)}")
    report = reports[0].parent
    return elapsed, json.loads(reports[0].read_text()), sum(
        path.stat().st_size for path in report.rglob("*") if path.is_file())

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kujo", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--routes", type=int, default=256)
    args = parser.parse_args()
    runtime = args.kujo.resolve(strict=True)
    driver = ROOT / "tests/fixtures/performance/profile_route_hotspot.kujo"
    _, driver_stdout = run([str(runtime), "run", str(driver), "--", str(args.routes)])
    micro = json.loads(driver_stdout.strip().splitlines()[-1])

    with tempfile.TemporaryDirectory(prefix="scout-route-profile-") as temp_name:
        temp = Path(temp_name)
        source = temp / "source"
        source.mkdir()
        (source / "routes.py").write_text("\n".join(
            f"@app.get('/profile/{index}')" for index in range(args.routes)) + "\n")
        quick_elapsed, quick_data, quick_bytes = scan(runtime, source, temp / "quick", True)
        full_elapsed, full_data, full_bytes = scan(runtime, source, temp / "full", False)

    comparable = (quick_data["routes"] == full_data["routes"] and
                  quick_data["dependencies"] == full_data["dependencies"] and
                  quick_data["security_findings"] == full_data["security_findings"])
    if not comparable or len(full_data["routes"]) != args.routes or micro["count"] != args.routes:
        raise SystemExit("profile workloads did not preserve route output equivalence")
    payload = {
        "tool": "scout-route-hotspot-profile-v1",
        "runtime_version": subprocess.check_output([str(runtime), "--version"], text=True).strip(),
        "routes": args.routes,
        "output_equivalent": comparable,
        "phases": {
            "array_rebuilding": {"elapsed_ms": round(micro["array_rebuild_ms"], 3), "method": "isolated repeated push"},
            "sorting": {"elapsed_ms": round(micro["sorting_ms"], 3), "method": "isolated sort_routes after accumulation"},
            "quick_scan": {"elapsed_seconds": round(quick_elapsed, 3), "report_bytes": quick_bytes},
            "full_scan": {"elapsed_seconds": round(full_elapsed, 3), "report_bytes": full_bytes},
            "report_assembly_proxy": {"elapsed_seconds": round(max(0.0, full_elapsed - quick_elapsed), 3),
                                      "additional_bytes": full_bytes - quick_bytes,
                                      "method": "full scan minus output-equivalent quick scan"}
        },
        "interpretation": "The report proxy includes full-mode document generation and publication overhead; timings are evidence, not portable thresholds."
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    print(f"Route hotspot profile passed: {args.output}")

if __name__ == "__main__":
    main()
