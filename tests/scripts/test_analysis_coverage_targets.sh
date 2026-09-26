#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"
cd "$REPO_ROOT"

receipt="tests/tmp/analysis-coverage.json"
python3 tests/scripts/measure_analysis_coverage.py \
  --kujo "$KUJO_BIN" \
  --targets tests/analysis_targets.json \
  --output "$receipt"
jq -e '.targets_passed == true and ([.metrics[]] | all(. == 1)) and (.families.routes | length == 18) and (.families.dependencies | length == 10)' "$receipt" >/dev/null
echo "Labeled analysis coverage target contract passed"
