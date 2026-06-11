#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/arc001"
OUT_ROOT="$REPO_ROOT/tests/tmp/arc001-output"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT"

"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$FIXTURE_DIR" -o "$OUT_ROOT" -d 4 > "$OUT_ROOT/run.log"

latest_dir="$(ls -1 "$OUT_ROOT" | head -n 1)"
if [[ -z "$latest_dir" ]]; then
	echo "No output directory generated"
	exit 1
fi

json_path="$OUT_ROOT/$latest_dir/intelligence.json"
if [[ ! -f "$json_path" ]]; then
	echo "Missing intelligence.json"
	exit 1
fi

languages_len="$(jq '.metrics.languages | length' "$json_path")"
if [[ "$languages_len" -lt 2 ]]; then
	echo "Expected at least 2 detected languages, got $languages_len"
	exit 1
fi

python_count="$(jq '.metrics.languages.Python // 0' "$json_path")"
js_count="$(jq '.metrics.languages.JavaScript // 0' "$json_path")"
if [[ "$python_count" -lt 1 || "$js_count" -lt 1 ]]; then
	echo "Expected Python and JavaScript counts >= 1; got Python=$python_count JS=$js_count"
	exit 1
fi

echo "ARC-001 language metrics regression test passed"
