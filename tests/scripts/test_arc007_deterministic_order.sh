#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/arc007"
OUT_A="$REPO_ROOT/tests/tmp/arc007-out-a"
OUT_B="$REPO_ROOT/tests/tmp/arc007-out-b"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

rm -rf "$OUT_A" "$OUT_B"
mkdir -p "$OUT_A" "$OUT_B"

"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$FIXTURE_DIR" -o "$OUT_A" -d 4 > "$OUT_A/run.log"
"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$FIXTURE_DIR" -o "$OUT_B" -d 4 > "$OUT_B/run.log"

dir_a="$(find "$OUT_A" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
dir_b="$(find "$OUT_B" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

json_a="$dir_a/intelligence.json"
json_b="$dir_b/intelligence.json"
readme_a="$dir_a/README.md"
readme_b="$dir_b/README.md"

for p in "$json_a" "$json_b" "$readme_a" "$readme_b"; do
	if [[ ! -f "$p" ]]; then
		echo "Missing expected output file: $p"
		exit 1
	fi
done

deps_keys="$(jq -r '.dependencies[] | (.module + "|" + .type + "|" + .source)' "$json_a")"
if [[ "$deps_keys" != "$(printf '%s\n' "$deps_keys" | sort)" ]]; then
	echo "Dependencies are not sorted deterministically"
	exit 1
fi

route_keys="$(jq -r '.routes[] | (.method + "|" + .path + "|" + .source)' "$json_a")"
if [[ "$route_keys" != "$(printf '%s\n' "$route_keys" | sort)" ]]; then
	echo "Routes are not sorted deterministically"
	exit 1
fi

security_keys="$(jq -r '.security_findings[] | ((if .severity=="critical" then "0" elif .severity=="high" then "1" elif .severity=="medium" then "2" else "3" end) + "|" + .file + "|" + (.line|tostring))' "$json_a")"
if [[ "$security_keys" != "$(printf '%s\n' "$security_keys" | sort -t'|' -k1,1 -k2,2 -k3,3n)" ]]; then
	echo "Security findings are not sorted deterministically"
	exit 1
fi

if ! diff -u "$readme_a" "$readme_b" >/dev/null; then
	echo "README output differs across repeated runs"
	exit 1
fi

echo "ARC-007 deterministic ordering regression test passed"
