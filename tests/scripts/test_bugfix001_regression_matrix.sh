#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/bugfix001"
OUT_ROOT="$REPO_ROOT/tests/tmp/bugfix001"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT"

"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$FIXTURE_DIR" -o "$OUT_ROOT/base" -d 6 > "$OUT_ROOT/base.log"
base_dir="$(find "$OUT_ROOT/base" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
base_json="$base_dir/intelligence.json"

assert_dependency() {
	local dep_type="$1"
	local module="$2"
	if ! jq -e --arg type "$dep_type" --arg module "$module" '.dependencies[] | select(.type == $type and .module == $module)' "$base_json" >/dev/null; then
		echo "Missing dependency: $dep_type $module"
		exit 1
	fi
}

# 1-2: compact JSON manifests must retain every dependency section.
assert_dependency npm_dependencies compact-npm
assert_dependency npm_devDependencies compact-npm-dev
assert_dependency composer_require vendor/compact
assert_dependency composer_require-dev vendor/compact-dev

# 3: comma-separated Python imports are separate modules without punctuation.
assert_dependency import os
assert_dependency import sys
if jq -e '.dependencies[] | select(.module == "os,")' "$base_json" >/dev/null; then
	echo "Python import retained trailing comma"
	exit 1
fi

# 4-6: source import syntax is normalized for PHP, Go blocks, and JVM static imports.
assert_dependency use 'Vendor\Package\Client'
assert_dependency go_import fmt
assert_dependency go_import example.com/pkg
assert_dependency jvm_import java.util.Collections.emptyList

# 7-8: root Next.js API files map to the root route.
if [[ "$(jq '[.routes[] | select(.path == "/" and .source == "pages/api/index.ts")] | length' "$base_json")" -ne 1 ]]; then
	echo "pages/api/index.ts did not map to /"
	exit 1
fi
if [[ "$(jq '[.routes[] | select(.path == "/" and .source == "app/api/route.ts")] | length' "$base_json")" -ne 1 ]]; then
	echo "app/api/route.ts did not map to /"
	exit 1
fi

# 9: a wildcard in the middle of a glob must match the intervening segment.
"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$FIXTURE_DIR" -o "$OUT_ROOT/glob" -d 6 --include 'src/*/file.py' > "$OUT_ROOT/glob.log"
glob_dir="$(find "$OUT_ROOT/glob" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
if [[ "$(jq '.metrics.total_files' "$glob_dir/intelligence.json")" -ne 1 ]]; then
	echo "Middle wildcard glob did not select exactly src/deep/file.py"
	exit 1
fi

# 10: findings in one file must sort by numeric line number.
security_lines="$(jq -r '.security_findings[] | select(.file == "security.py") | .line' "$base_json")"
if [[ "$security_lines" != $'2\n10' ]]; then
	echo "Security findings are not numerically line-sorted: $security_lines"
	exit 1
fi

echo "BUGFIX-001 ten-bug regression matrix passed"
