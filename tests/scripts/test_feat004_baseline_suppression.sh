#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/feat004"
OUT_ROOT="$REPO_ROOT/tests/tmp/feat004-output"
GENERATED_BASELINE="$FIXTURE_DIR/generated-baseline.json"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

cleanup() {
	rm -f "$GENERATED_BASELINE"
}
trap cleanup EXIT

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT"

run_case() {
	local name="$1"
	shift
	"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$FIXTURE_DIR" -o "$OUT_ROOT/$name" -d 3 "$@" > "$OUT_ROOT/$name.log"
	find "$OUT_ROOT/$name" -mindepth 1 -maxdepth 1 -type d | head -n 1
}

base_dir="$(run_case base)"
base_json="$base_dir/intelligence.json"

if [[ "$(jq '.security_findings_total' "$base_json")" -ne 2 ]]; then
	echo "Expected total security findings to remain 2"
	exit 1
fi

if [[ "$(jq '.security_findings | length' "$base_json")" -ne 1 ]]; then
	echo "Expected one visible finding with baseline suppression"
	exit 1
fi

if [[ "$(jq '.suppressed_security_findings | length' "$base_json")" -ne 1 ]]; then
	echo "Expected one suppressed finding from fixture baseline"
	exit 1
fi

if [[ "$(jq -r '.security_findings[0].label' "$base_json")" != "Hardcoded token" ]]; then
	echo "Expected unsuppressed finding to be Hardcoded token"
	exit 1
fi

show_dir="$(run_case show --show-suppressed)"
show_json="$show_dir/intelligence.json"

if [[ "$(jq '.security_findings | length' "$show_json")" -ne 2 ]]; then
	echo "Expected --show-suppressed to include all findings"
	exit 1
fi

if [[ "$(jq '[.security_findings[] | select(.suppressed == true)] | length' "$show_json")" -ne 1 ]]; then
	echo "Expected exactly one suppressed finding in show-suppressed output"
	exit 1
fi

write_dir="$(run_case write --write-baseline --baseline generated-baseline.json)"
write_json="$write_dir/intelligence.json"

if [[ ! -f "$GENERATED_BASELINE" ]]; then
	echo "Expected generated baseline file to be written"
	exit 1
fi

if [[ "$(jq '.fingerprints | length' "$GENERATED_BASELINE")" -ne 2 ]]; then
	echo "Expected generated baseline to include two fingerprints"
	exit 1
fi

if [[ "$(jq -r '.flags.write_baseline' "$write_json")" != "true" ]]; then
	echo "Expected write_baseline flag to be true"
	exit 1
fi

generated_dir="$(run_case generated --baseline generated-baseline.json)"
generated_json="$generated_dir/intelligence.json"

if [[ "$(jq '.security_findings | length' "$generated_json")" -ne 0 ]]; then
	echo "Expected generated baseline to suppress all findings"
	exit 1
fi

if [[ "$(jq '.suppressed_security_findings | length' "$generated_json")" -ne 2 ]]; then
	echo "Expected two suppressed findings with generated baseline"
	exit 1
fi

echo "FEAT-004 baseline suppression regression test passed"