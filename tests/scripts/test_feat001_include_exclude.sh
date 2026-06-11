#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/feat001"
OUT_ROOT="$REPO_ROOT/tests/tmp/feat001-output"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT"

run_case() {
	local name="$1"
	shift
	"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$FIXTURE_DIR" -o "$OUT_ROOT/$name" "$@" > "$OUT_ROOT/$name.log"
	find "$OUT_ROOT/$name" -mindepth 1 -maxdepth 1 -type d | head -n 1
}

base_dir="$(run_case base)"
base_json="$base_dir/intelligence.json"
if [[ "$(jq '.metrics.languages.JavaScript // 0' "$base_json")" -ne 1 ]]; then
	echo "Expected .scoutignore to exclude one JS file in base run"
	exit 1
fi

py_only_dir="$(run_case py_only --include '*.py')"
py_only_json="$py_only_dir/intelligence.json"
if [[ "$(jq '.metrics.languages.JavaScript // 0' "$py_only_json")" -ne 0 ]]; then
	echo "Expected --include '*.py' to exclude JavaScript files"
	exit 1
fi
if [[ "$(jq '.metrics.languages.Python // 0' "$py_only_json")" -lt 1 ]]; then
	echo "Expected --include '*.py' to include Python files"
	exit 1
fi

no_py_dir="$(run_case no_py --exclude '*.py')"
no_py_json="$no_py_dir/intelligence.json"
if [[ "$(jq '.metrics.languages.Python // 0' "$no_py_json")" -ne 0 ]]; then
	echo "Expected --exclude '*.py' to exclude Python files"
	exit 1
fi
if [[ "$(jq '.metrics.languages.JavaScript // 0' "$no_py_json")" -lt 1 ]]; then
	echo "Expected --exclude '*.py' to keep JavaScript files"
	exit 1
fi

echo "FEAT-001 include/exclude + ignore regression test passed"
