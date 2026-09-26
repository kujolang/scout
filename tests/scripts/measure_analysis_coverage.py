#!/usr/bin/env python3
"""Measure exact-match, per-family analysis precision and recall."""

import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
CORPUS = ROOT / "tests/fixtures/analysis-corpus"

def scan(runtime, fixture, output, *flags):
    subprocess.run([str(runtime), "run", str(ROOT / "scout.kujo"), "--", str(fixture),
                    "-o", str(output), "-d", "8", "--quick", "--strict", *flags],
                   cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
    reports = list(output.glob("*/intelligence.json"))
    if len(reports) != 1:
        raise RuntimeError(f"expected one report for {fixture}, found {len(reports)}")
    return json.loads(reports[0].read_text())

def score(expected, actual):
    expected, actual = set(expected), set(actual)
    tp, fp, fn = len(expected & actual), len(actual - expected), len(expected - actual)
    return {"true_positives": tp, "false_positives": fp, "false_negatives": fn,
            "precision": tp / (tp + fp) if tp + fp else 1.0,
            "recall": tp / (tp + fn) if tp + fn else 1.0,
            "unexpected": sorted(actual - expected), "missing": sorted(expected - actual)}

def collect_family(runtime, kind, expected_by_family, temporary):
    results, aggregate_expected, aggregate_actual = {}, set(), set()
    for family, expected in sorted(expected_by_family.items()):
        flags = ["--skip-deps", "--skip-security"] if kind == "routes" else ["--skip-routes", "--skip-security"]
        if family == "javascript_fastify":
            flags += ["--rule", "fastify-object"]
        result = scan(runtime, CORPUS / kind / family, temporary / f"{kind}-{family}", *flags)
        if kind == "routes":
            actual = {f"{item['method']}|{item['path']}" for item in result["routes"]}
        else:
            actual = {f"{item['type']}|{item['module']}" for item in result["dependencies"]}
        results[family] = score(expected, actual)
        aggregate_expected.update(f"{family}|{item}" for item in expected)
        aggregate_actual.update(f"{family}|{item}" for item in actual)
    return results, score(aggregate_expected, aggregate_actual)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kujo", type=Path, required=True)
    parser.add_argument("--targets", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    targets = json.loads(args.targets.read_text())
    labels = json.loads((CORPUS / "labels.json").read_text())
    expected_security = {
        "dangerous_exec.js|Dangerous code execution function", "embedded_private_key.py|Embedded private key",
        "hardcoded_credential.py|Hardcoded credential", "hardcoded_token.py|Hardcoded token",
        "insecure_deserialization.py|Insecure deserialization", "weak_hash.py|Weak hash usage",
        "xss_sink.js|XSS sink usage", "security_true_positive_credential.py|Hardcoded credential",
        "security_true_positive_exec.js|Dangerous code execution function"}
    actual_security = set()
    with tempfile.TemporaryDirectory(prefix="scout-analysis-coverage-") as temp_name:
        temp = Path(temp_name)
        route_families, route_score = collect_family(args.kujo, "routes", labels["routes"], temp)
        dependency_families, dependency_score = collect_family(args.kujo, "dependencies", labels["dependencies"], temp)
        for index, fixture in enumerate((ROOT / "tests/fixtures/test006", ROOT / "tests/fixtures/test003")):
            result = scan(args.kujo, fixture, temp / f"security-{index}", "--skip-deps", "--skip-routes")
            actual_security.update(f"{Path(item['file']).name}|{item['label']}" for item in result["security_findings"])
    security_score = score(expected_security, actual_security)
    metrics = {"route_precision": route_score["precision"], "route_recall": route_score["recall"],
               "dependency_precision": dependency_score["precision"], "dependency_recall": dependency_score["recall"],
               "security_precision": security_score["precision"], "security_recall": security_score["recall"],
               "minimum_route_family_precision": min(item["precision"] for item in route_families.values()),
               "minimum_route_family_recall": min(item["recall"] for item in route_families.values()),
               "minimum_dependency_family_precision": min(item["precision"] for item in dependency_families.values()),
               "minimum_dependency_family_recall": min(item["recall"] for item in dependency_families.values())}
    failures = [name for name, minimum in targets["minimums"].items() if metrics[name] < minimum]
    payload = {"tool": "scout-analysis-coverage-v2",
               "runtime_version": subprocess.check_output([str(args.kujo), "--version"], text=True).strip(),
               "target_contract": targets["contract"], "targets_passed": not failures, "metrics": metrics,
               "families": {"routes": route_families, "dependencies": dependency_families},
               "route": route_score, "dependency": dependency_score, "security": security_score}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    if failures:
        raise SystemExit("analysis coverage targets failed: " + ", ".join(failures))
    print(f"Analysis coverage targets passed: {args.output}")

if __name__ == "__main__":
    main()
