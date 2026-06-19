#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/feat010_dependency_manifests"
OUT_ROOT="$REPO_ROOT/tests/tmp/feat010-output"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT"

"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$FIXTURE_DIR" -o "$OUT_ROOT" -d 2 --skip-routes --skip-security > "$OUT_ROOT/run.log"
out_dir="$(find "$OUT_ROOT" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
json_path="$out_dir/intelligence.json"

if [[ ! -f "$json_path" ]]; then
	echo "Missing intelligence.json"
	exit 1
fi

assert_dependency() {
	local dep_type="$1"
	local module="$2"
	local count
	count="$(jq --arg dep_type "$dep_type" --arg module "$module" '[.dependencies[] | select(.type == $dep_type and .module == $module)] | length' "$json_path")"
	if [[ "$count" -ne 1 ]]; then
		echo "Expected dependency $dep_type:$module"
		exit 1
	fi
}

assert_dependency "pubspec_dependencies" "http"
assert_dependency "pubspec_dev_dependencies" "devtools"
assert_dependency "swift_package" "https://github.com/apple/swift-argument-parser"
assert_dependency "mix_dep" "plug"
assert_dependency "mix_dep" "jason"

if [[ "$(jq '[.dependencies[] | select(.module == "path")] | length' "$json_path")" -ne 0 ]]; then
	echo "Expected pubspec nested path metadata to be ignored as a package dependency"
	exit 1
fi

echo "FEAT-010 dependency manifest regression test passed"
