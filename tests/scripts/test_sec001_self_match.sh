#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/sec001"
OUT_ROOT="$REPO_ROOT/tests/tmp/sec001-output"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT"

"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$FIXTURE_DIR" -o "$OUT_ROOT" -d 3 > "$OUT_ROOT/run.log"
out_dir="$(find "$OUT_ROOT" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
json_path="$out_dir/intelligence.json"

if [[ ! -f "$json_path" ]]; then
	echo "Missing intelligence.json"
	exit 1
fi

findings_len="$(jq '.security_findings | length' "$json_path")"
if [[ "$findings_len" -ne 1 ]]; then
	echo "Expected exactly 1 security finding, got $findings_len"
	exit 1
fi

snippet="$(jq -r '.security_findings[0].snippet' "$json_path")"
if [[ "$snippet" != *'password = "real-secret"'* ]]; then
	echo "Unexpected finding snippet: $snippet"
	exit 1
fi

echo "SEC-001 self-match regression test passed"
