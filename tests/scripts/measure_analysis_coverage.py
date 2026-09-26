#!/usr/bin/env python3
"""Measure exact-match route/security precision and recall on labeled fixtures."""

import argparse
import json
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]


def scan(runtime, fixture, output, *flags):
    subprocess.run(
        [str(runtime), "run", str(ROOT / "scout.kujo"), "--", str(fixture),
         "-o", str(output), "-d", "4", "--quick", "--strict", *flags],
        cwd=ROOT, check=True, stdout=subprocess.DEVNULL,
    )
    reports = list(output.glob("*/intelligence.json"))
    if len(reports) != 1:
        raise RuntimeError(f"expected one report for {fixture}, found {len(reports)}")
    return json.loads(reports[0].read_text())


def score(expected, actual):
    expected, actual = set(expected), set(actual)
    tp = len(expected & actual)
    fp = len(actual - expected)
    fn = len(expected - actual)
    precision = tp / (tp + fp) if tp + fp else 1.0
    recall = tp / (tp + fn) if tp + fn else 1.0
    return {"true_positives": tp, "false_positives": fp, "false_negatives": fn,
            "precision": precision, "recall": recall,
            "unexpected": sorted(actual - expected), "missing": sorted(expected - actual)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kujo", type=Path, required=True)
    parser.add_argument("--targets", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    targets = json.loads(args.targets.read_text())

    expected_routes = set()
    actual_routes = set()
    route_root = ROOT / "tests/fixtures/test002"
    expected_by_case = {path.stem: path.read_text().strip()
                        for path in (route_root / "snapshots").glob("*.txt")}

    expected_security = {
        "dangerous_exec.js|Dangerous code execution function",
        "embedded_private_key.py|Embedded private key",
        "hardcoded_credential.py|Hardcoded credential",
        "hardcoded_token.py|Hardcoded token",
        "insecure_deserialization.py|Insecure deserialization",
        "weak_hash.py|Weak hash usage",
        "xss_sink.js|XSS sink usage",
        "security_true_positive_credential.py|Hardcoded credential",
        "security_true_positive_exec.js|Dangerous code execution function",
    }
    actual_security = set()

    with tempfile.TemporaryDirectory(prefix="scout-analysis-coverage-") as temporary:
        temp = Path(temporary)
        for case, expected in sorted(expected_by_case.items()):
            result = scan(args.kujo, route_root / f"routes_{case}", temp / f"route-{case}",
                          "--skip-deps", "--skip-security")
            expected_routes.add(f"{case}|{expected}")
            actual_routes.update(f"{case}|{route['method']}|{route['path']}"
                                 for route in result["routes"])
        for index, fixture in enumerate((ROOT / "tests/fixtures/test006",
                                         ROOT / "tests/fixtures/test003")):
            result = scan(args.kujo, fixture, temp / f"security-{index}",
                          "--skip-deps", "--skip-routes")
            actual_security.update(f"{Path(item['file']).name}|{item['label']}"
                                   for item in result["security_findings"])

    route_score = score(expected_routes, actual_routes)
    security_score = score(expected_security, actual_security)
    metrics = {
        "route_precision": route_score["precision"],
        "route_recall": route_score["recall"],
        "security_precision": security_score["precision"],
        "security_recall": security_score["recall"],
    }
    failures = [name for name, minimum in targets["minimums"].items()
                if metrics[name] < minimum]
    payload = {"tool": "scout-analysis-coverage-v1", "runtime_version":
               subprocess.check_output([str(args.kujo), "--version"], text=True).strip(),
               "target_contract": targets["contract"], "targets_passed": not failures,
               "metrics": metrics, "route": route_score, "security": security_score}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    if failures:
        raise SystemExit("analysis coverage targets failed: " + ", ".join(failures))
    print(f"Analysis coverage targets passed: {args.output}")


if __name__ == "__main__":
    main()
