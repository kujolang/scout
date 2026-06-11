#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_ROOT="$REPO_ROOT/tests/tmp/arc006-fixture"
OUT_ROOT="$REPO_ROOT/tests/tmp/arc006-output"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

rm -rf "$FIXTURE_ROOT" "$OUT_ROOT"
mkdir -p "$FIXTURE_ROOT/src" "$OUT_ROOT"

for i in $(seq 1 12); do
	file="$FIXTURE_ROOT/src/file_$i.js"
	{
		echo "// file $i"
		for _ in $(seq 1 "$i"); do
			echo "console.log('x');"
		done
	} > "$file"
done

"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$FIXTURE_ROOT" -o "$OUT_ROOT" -d 4 > "$OUT_ROOT/run.log"
out_dir="$(find "$OUT_ROOT" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
json_path="$out_dir/intelligence.json"

if [[ ! -f "$json_path" ]]; then
	echo "Missing intelligence.json"
	exit 1
fi

largest_count="$(jq '.metrics.largest_files | length' "$json_path")"
if [[ "$largest_count" -ne 10 ]]; then
	echo "Expected 10 largest files, got $largest_count"
	exit 1
fi

top_name="$(jq -r '.metrics.largest_files[0].name' "$json_path")"
if [[ "$top_name" != "file_12.js" ]]; then
	echo "Expected largest file_12.js first, got $top_name"
	exit 1
fi

# Verify descending sizes.
prev=0
idx=0
while [[ $idx -lt 10 ]]; do
	cur="$(jq ".metrics.largest_files[$idx].size" "$json_path")"
	if [[ $idx -gt 0 && "$cur" -gt "$prev" ]]; then
		echo "Largest files are not sorted descending at index $idx"
		exit 1
	fi
	prev="$cur"
	idx=$((idx+1))
done

echo "ARC-006 largest-files top-k regression test passed"
