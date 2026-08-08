#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_REL="tests/fixtures/arc001"
OUT_ROOT="$REPO_ROOT/tests/tmp/test005-output"
SNAPSHOT_DIR="$REPO_ROOT/tests/fixtures/test005/snapshots"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT"

cd "$REPO_ROOT"
"$KUJO_BIN" run scout.kujo "$TARGET_REL" -o tests/tmp/test005-output -d 3 > "$OUT_ROOT/run.log"
out_dir="$(find "$OUT_ROOT" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

if [[ -z "$out_dir" ]]; then
	echo "No output directory generated"
	exit 1
fi

compare_text() {
	local generated_file="$1"
	local snapshot_file="$2"
	if [[ ! -f "$snapshot_file" ]]; then
		echo "Missing snapshot: $snapshot_file"
		exit 1
	fi
	if ! diff -u "$snapshot_file" "$generated_file" >/dev/null; then
		echo "Snapshot mismatch: $(basename "$generated_file")"
		diff -u "$snapshot_file" "$generated_file" || true
		exit 1
	fi
}

compare_text "$out_dir/llms.txt" "$SNAPSHOT_DIR/llms.txt"

norm_intel="$(mktemp)"
norm_manifest="$(mktemp)"
trap 'rm -f "$norm_intel" "$norm_manifest"' EXIT

jq -S '.output = "__OUTPUT__" | .output_root = "__OUTPUT_ROOT__" | .run_timestamp = "__RUN_TS__"' "$out_dir/intelligence.json" > "$norm_intel"
jq -S '.output = "__OUTPUT__" | .generated_at = "__GENERATED_AT__"' "$out_dir/scan_manifest.json" > "$norm_manifest"

compare_text "$norm_intel" "$SNAPSHOT_DIR/intelligence.json"
compare_text "$norm_manifest" "$SNAPSHOT_DIR/scan_manifest.json"

echo "TEST-005 golden snapshot regression test passed"
