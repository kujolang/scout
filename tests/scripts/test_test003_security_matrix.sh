#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/test003"
OUT_ROOT="$REPO_ROOT/tests/tmp/test003-output"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT"

"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$FIXTURE_DIR" -o "$OUT_ROOT" -d 3 --skip-deps --skip-routes > "$OUT_ROOT/run.log"
out_dir="$(find "$OUT_ROOT" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
json_path="$out_dir/intelligence.json"

if [[ ! -f "$json_path" ]]; then
	echo "Missing intelligence.json"
	exit 1
fi

findings_count="$(jq '.security_findings | length' "$json_path")"
if [[ "$findings_count" -ne 2 ]]; then
	echo "Expected exactly 2 security findings (precision matrix baseline), got $findings_count"
	exit 1
fi

credential_count="$(jq '[.security_findings[] | select(.label == "Hardcoded credential")] | length' "$json_path")"
exec_count="$(jq '[.security_findings[] | select(.label == "Dangerous code execution function")] | length' "$json_path")"

if [[ "$credential_count" -ne 1 || "$exec_count" -ne 1 ]]; then
	echo "Expected one credential and one dangerous-exec finding"
	exit 1
fi

false_positive_count="$(jq '[.security_findings[] | select(.file | test("false_positive"))] | length' "$json_path")"
if [[ "$false_positive_count" -ne 0 ]]; then
	echo "Expected zero false-positive fixture findings"
	exit 1
fi

echo "TEST-003 security precision matrix passed"