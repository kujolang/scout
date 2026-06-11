#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_ROOT="$REPO_ROOT/tests/fixtures/test001"
OUT_ROOT="$REPO_ROOT/tests/tmp/test001-output"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT"

run_case() {
	local name="$1"
	local target="$2"
	shift 2
	"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$target" -o "$OUT_ROOT/$name" -d 3 "$@" > "$OUT_ROOT/$name.log"
	find "$OUT_ROOT/$name" -mindepth 1 -maxdepth 1 -type d | head -n 1
}

deps_pos_dir="$(run_case deps_pos "$FIXTURE_ROOT/dependencies_positive" --skip-routes --skip-security)"
deps_neg_dir="$(run_case deps_neg "$FIXTURE_ROOT/dependencies_negative" --skip-routes --skip-security)"

deps_pos_json="$deps_pos_dir/intelligence.json"
deps_neg_json="$deps_neg_dir/intelligence.json"

if [[ "$(jq '.dependencies | length' "$deps_pos_json")" -lt 1 ]]; then
	echo "Expected dependency-positive fixture to produce dependencies"
	exit 1
fi

if [[ "$(jq '.dependencies | length' "$deps_neg_json")" -ne 0 ]]; then
	echo "Expected dependency-negative fixture to produce zero dependencies"
	exit 1
fi

routes_pos_dir="$(run_case routes_pos "$FIXTURE_ROOT/routes_positive" --skip-deps --skip-security)"
routes_neg_dir="$(run_case routes_neg "$FIXTURE_ROOT/routes_negative" --skip-deps --skip-security)"

routes_pos_json="$routes_pos_dir/intelligence.json"
routes_neg_json="$routes_neg_dir/intelligence.json"

if [[ "$(jq '.routes | length' "$routes_pos_json")" -lt 1 ]]; then
	echo "Expected route-positive fixture to produce routes"
	exit 1
fi

if [[ "$(jq '.routes | length' "$routes_neg_json")" -ne 0 ]]; then
	echo "Expected route-negative fixture to produce zero routes"
	exit 1
fi

sec_pos_dir="$(run_case sec_pos "$FIXTURE_ROOT/security_positive" --skip-deps --skip-routes)"
sec_neg_dir="$(run_case sec_neg "$FIXTURE_ROOT/security_negative" --skip-deps --skip-routes)"

sec_pos_json="$sec_pos_dir/intelligence.json"
sec_neg_json="$sec_neg_dir/intelligence.json"

if [[ "$(jq '.security_findings | length' "$sec_pos_json")" -lt 1 ]]; then
	echo "Expected security-positive fixture to produce findings"
	exit 1
fi

if [[ "$(jq '.security_findings | length' "$sec_neg_json")" -ne 0 ]]; then
	echo "Expected security-negative fixture to produce zero findings"
	exit 1
fi

echo "TEST-001 fixture analyzer suite passed"