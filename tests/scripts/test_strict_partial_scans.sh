#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"
cd "$REPO_ROOT"

work="tests/tmp/strict-partial"
rm -rf "$work"
mkdir -p "$work/target" "$work/reports"
printf 'import pathlib\n' > "$work/target/large.py"
dd if=/dev/zero bs=1048576 count=2 >> "$work/target/large.py" 2>/dev/null
ln -s absent.py "$work/target/unavailable.py"
printf '{"fingerprints":["accepted-old"]}\n' > "$work/baseline.json"
cp "$work/baseline.json" "$work/previous.json"

"$KUJO_BIN" run scout.kujo -- tests/fixtures/strict -o "$work/reports" --strict > "$work/complete.log"
set +e
"$KUJO_BIN" run scout.kujo -- "$work/target" -o "$work/reports" > "$work/default.log"
default_status=$?
"$KUJO_BIN" run scout.kujo -- "$work/target" -o "$work/reports" --strict --write-baseline --baseline "$REPO_ROOT/$work/baseline.json" > "$work/strict.log"
strict_status=$?
set -e
test "$default_status" -eq 0
test "$strict_status" -eq 2
cmp "$work/previous.json" "$work/baseline.json"
run_dir="$(awk -F': ' '/^Output: /{print $2}' "$work/strict.log" | tail -n 1)"
test -f "$run_dir/scan_manifest.json"
jq -e '.flags.strict_scan == true and ([.parse_errors[].error] | index("truncated_500000b") != null and index("path_unavailable") != null)' "$run_dir/intelligence.json" >/dev/null
rg -q 'Strict scan failed: 2 diagnostic' "$work/strict.log"

printf '{"analysis":{"strict_scan":true},"output":{"default_dir":"%s"}}\n' "$REPO_ROOT/$work/reports" > "$work/config.json"
set +e
(cd "$work" && "$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$REPO_ROOT/$work/target" > "$REPO_ROOT/$work/config.log")
config_status=$?
set -e
test "$config_status" -eq 2
echo "Strict opt-in, default compatibility, config, and baseline retention passed"
