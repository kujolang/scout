#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_ROOT="$REPO_ROOT/tests/fixtures/test002"
OUT_ROOT="$REPO_ROOT/tests/tmp/test002-output"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT"

run_case() {
	local case_name="$1"
	local fixture_path="$2"
	"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$fixture_path" -o "$OUT_ROOT/$case_name" -d 3 --skip-deps --skip-security > "$OUT_ROOT/$case_name.log"
	find "$OUT_ROOT/$case_name" -mindepth 1 -maxdepth 1 -type d | head -n 1
}

assert_snapshot() {
	local case_name="$1"
	local fixture_path="$2"
	local snapshot_path="$3"

	out_dir="$(run_case "$case_name" "$fixture_path")"
	json_path="$out_dir/intelligence.json"

	if [[ "$(jq '.routes | length' "$json_path")" -ne 1 ]]; then
		echo "Expected exactly 1 route in $case_name fixture"
		exit 1
	fi

	actual="$(jq -r '.routes[0].method + "|" + .routes[0].path' "$json_path")"
	expected="$(tr -d '\r\n' < "$snapshot_path")"

	if [[ "$actual" != "$expected" ]]; then
		echo "Route snapshot mismatch for $case_name"
		echo "Expected: $expected"
		echo "Actual:   $actual"
		exit 1
	fi
}

assert_snapshot python "$FIXTURE_ROOT/routes_python" "$FIXTURE_ROOT/snapshots/python.txt"
assert_snapshot js "$FIXTURE_ROOT/routes_js" "$FIXTURE_ROOT/snapshots/js.txt"
assert_snapshot php "$FIXTURE_ROOT/routes_php" "$FIXTURE_ROOT/snapshots/php.txt"
assert_snapshot rust "$FIXTURE_ROOT/routes_rust" "$FIXTURE_ROOT/snapshots/rust.txt"
assert_snapshot go "$FIXTURE_ROOT/routes_go" "$FIXTURE_ROOT/snapshots/go.txt"
assert_snapshot jvm "$FIXTURE_ROOT/routes_jvm" "$FIXTURE_ROOT/snapshots/jvm.txt"
assert_snapshot kujo "$FIXTURE_ROOT/routes_kujo" "$FIXTURE_ROOT/snapshots/kujo.txt"

echo "TEST-002 route matrix regression test passed"