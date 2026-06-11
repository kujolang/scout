#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/arc001"
DOT_FIXTURE_DIR="$REPO_ROOT/tests/tmp/arc002-dot-target"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

extract_slug_prefix() {
	local base_name="$1"
	echo "$base_name" | sed -E 's/-[0-9]{8}-[0-9]{6}-[0-9]+$//'
}

run_case() {
	local target="$1"
	local out_root="$2"
	local expected_prefix="$3"
	local run_cwd="$4"

	rm -rf "$out_root"
	mkdir -p "$out_root"

	(
		cd "$run_cwd"
		"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$target" -o "$out_root" -d 3 > "$out_root/run.log"
	)

	local out_dir
	out_dir="$(awk -F': ' '/^Output: /{print $2}' "$out_root/run.log" | tail -n 1)"
	if [[ -z "$out_dir" ]]; then
		echo "No output path in run log for target=$target"
		exit 1
	fi

	local base_name
	base_name="$(basename "$out_dir")"
	if [[ "$base_name" == .-* ]]; then
		echo "Output folder still uses dot-prefixed slug for target=$target: $base_name"
		exit 1
	fi
	if [[ "$base_name" == *" "* ]]; then
		echo "Output folder contains spaces for target=$target: $base_name"
		exit 1
	fi

	local prefix
	prefix="$(extract_slug_prefix "$base_name")"
	if [[ "$prefix" != "$expected_prefix" ]]; then
		echo "Unexpected slug prefix for target=$target. expected=$expected_prefix got=$prefix"
		exit 1
	fi
}

rm -rf "$DOT_FIXTURE_DIR"
mkdir -p "$DOT_FIXTURE_DIR/src"
printf 'print("hello")\n' > "$DOT_FIXTURE_DIR/src/app.kujo"

run_case "." "$REPO_ROOT/tests/tmp/arc002-dot" "arc002-dot-target" "$DOT_FIXTURE_DIR"
run_case "tests/fixtures/arc001" "$REPO_ROOT/tests/tmp/arc002-rel" "arc001" "$REPO_ROOT"
run_case "$FIXTURE_DIR" "$REPO_ROOT/tests/tmp/arc002-abs" "arc001" "$REPO_ROOT"

echo "ARC-002 slug sanitization regression test passed"
