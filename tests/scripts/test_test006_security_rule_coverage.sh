#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/test006"
OUT_ROOT="$REPO_ROOT/tests/tmp/test006-output"

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

assert_label_present() {
	local label="$1"
	local count
	count="$(jq --arg label "$label" '[.security_findings[] | select(.label == $label)] | length' "$json_path")"
	if [[ "$count" -lt 1 ]]; then
		echo "Expected at least one finding for label: $label"
		exit 1
	fi
}

assert_label_present "Hardcoded credential"
assert_label_present "Hardcoded token"
assert_label_present "Embedded private key"
assert_label_present "Dangerous code execution function"
assert_label_present "XSS sink usage"
assert_label_present "Insecure deserialization"
assert_label_present "Weak hash usage"

total_findings="$(jq '.security_findings | length' "$json_path")"
if [[ "$total_findings" -lt 7 ]]; then
	echo "Expected at least 7 findings from coverage matrix, got $total_findings"
	exit 1
fi

echo "TEST-006 security rule coverage passed"
