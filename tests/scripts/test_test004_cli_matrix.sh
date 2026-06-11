#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_REL="tests/fixtures/arc003"
OUT_ROOT="$REPO_ROOT/tests/tmp/test004-output"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

run_expect_fail() {
	local expected="$1"
	shift

	set +e
	output="$($@ 2>&1)"
	status="$?"
	set -e

	if [[ "$status" -eq 0 ]]; then
		echo "Expected command to fail with non-zero exit status"
		echo "Actual status: $status"
		echo "Actual output: $output"
		exit 1
	fi

	if [[ "$output" != *"$expected"* ]]; then
		echo "Expected error output to contain: $expected"
		echo "Actual output: $output"
		exit 1
	fi
}

run_expect_success() {
	local expected="$1"
	shift

	set +e
	output="$($@ 2>&1)"
	status="$?"
	set -e

	if [[ "$status" -ne 0 ]]; then
		echo "Expected command to succeed"
		echo "Actual status: $status"
		echo "Actual output: $output"
		exit 1
	fi

	if [[ -n "$expected" && "$output" != *"$expected"* ]]; then
		echo "Expected output to contain: $expected"
		echo "Actual output: $output"
		exit 1
	fi
}

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT"

cd "$REPO_ROOT"

run_expect_success "Scout" "$KUJO_BIN" run scout.kujo -- --help
run_expect_success "1.0.0" "$KUJO_BIN" run scout.kujo -- --version

run_expect_fail "Error: unknown option: --unknown-flag" "$KUJO_BIN" run scout.kujo -- "$TARGET_REL" --unknown-flag
run_expect_fail "Error: missing value for -o" "$KUJO_BIN" run scout.kujo -- "$TARGET_REL" -o
run_expect_fail "Error: invalid max depth: nope" "$KUJO_BIN" run scout.kujo -- "$TARGET_REL" -d nope
run_expect_fail "Error: invalid max depth: -1" "$KUJO_BIN" run scout.kujo -- "$TARGET_REL" -d -1
run_expect_fail "Error: invalid path mode: weird" "$KUJO_BIN" run scout.kujo -- "$TARGET_REL" --path-mode weird
run_expect_fail "Error: target path not found: /tmp/scout-missing-target-test004" "$KUJO_BIN" run scout.kujo -- /tmp/scout-missing-target-test004

"$KUJO_BIN" run scout.kujo -- -d 2 -o tests/tmp/test004-output/success --skip-deps --skip-routes --skip-security "$TARGET_REL" > "$OUT_ROOT/success.log"
out_dir="$(find "$OUT_ROOT/success" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
json_path="$out_dir/intelligence.json"

if [[ ! -f "$json_path" ]]; then
	echo "Missing intelligence.json for successful CLI matrix case"
	exit 1
fi

if [[ "$(jq '.flags.max_depth' "$json_path")" -ne 2 ]]; then
	echo "Expected --max-depth 2 to be applied"
	exit 1
fi

if [[ "$(jq -r '.flags.skip_dependencies' "$json_path")" != "true" ]]; then
	echo "Expected --skip-deps to be applied"
	exit 1
fi

if [[ "$(jq -r '.flags.skip_routes' "$json_path")" != "true" ]]; then
	echo "Expected --skip-routes to be applied"
	exit 1
fi

if [[ "$(jq -r '.flags.skip_security' "$json_path")" != "true" ]]; then
	echo "Expected --skip-security to be applied"
	exit 1
fi

if [[ "$(jq -r '.target' "$json_path")" != "$TARGET_REL" ]]; then
	echo "Expected positional target to resolve to $TARGET_REL"
	exit 1
fi

echo "TEST-004 CLI matrix regression test passed"
