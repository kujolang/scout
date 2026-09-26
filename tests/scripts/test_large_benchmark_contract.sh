#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"
cd "$REPO_ROOT"

first="tests/tmp/large-benchmark-first.json"
second="tests/tmp/large-benchmark-second.json"
python3 tests/scripts/benchmark_large_scans.py --kujo "$KUJO_BIN" --output "$first" --fast --targets tests/performance_targets.json
python3 tests/scripts/benchmark_large_scans.py --kujo "$KUJO_BIN" --output "$second" --fast --targets tests/performance_targets.json
jq -e '.tool == "scout-large-benchmark-v2" and .mode == "fast" and .targets_passed == true and (.target_evaluations | length == 3) and (.measurements | length == 3) and (.measurements.large_source.diagnostics == 2) and ([.measurements[] | select(.peak_rss_bytes > 0 and .elapsed_seconds > 0 and .report_bytes > 0)] | length == 3)' "$first" >/dev/null
cmp <(jq -S '[.measurements[].fixture_sha256]' "$first") <(jq -S '[.measurements[].fixture_sha256]' "$second")
echo "Deterministic large benchmark workload and receipt contract passed"
