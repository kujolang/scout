#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"
cd "$REPO_ROOT"

work="tests/tmp/recoverable-publication"
rm -rf "$work"
mkdir -p "$work/reports" "$work/baseline"
baseline="$work/baseline/accepted.json"
baseline_abs="$REPO_ROOT/$baseline"
printf '{"fingerprints":["accepted-old"]}\n' > "$baseline"
cp "$baseline" "$work/previous.json"

# Restrict the child to a small output file; this interrupts publication after
# staging begins without touching source or the previously accepted baseline.
set +e
(ulimit -f 1; "$KUJO_BIN" run scout.kujo -- tests/fixtures/publication -o "$work/reports" --write-baseline --baseline "$baseline_abs" > /dev/null 2> "$work/failure.log")
status=$?
set -e
if [[ "$status" -eq 0 ]]; then
    echo "Expected injected output write failure"
    exit 1
fi
cmp "$baseline" "$work/previous.json"
if find "$work/reports" -mindepth 1 -maxdepth 1 -type d ! -name '.scout-stage-*' | grep -q .; then
    echo "Failed scan published an incomplete report"
    exit 1
fi

# Force the baseline's atomic temporary write to fail after the report has
# published. The previous file must remain readable and byte-for-byte intact.
chmod 0500 "$work/baseline"
trap 'chmod 0700 "$work/baseline"' EXIT
set +e
"$KUJO_BIN" run scout.kujo -- tests/fixtures/publication -o "$work/reports" --write-baseline --baseline "$baseline_abs" > "$work/denied.log" 2>&1
status=$?
set -e
chmod 0700 "$work/baseline"
trap - EXIT
if [[ "$status" -eq 0 ]]; then
    echo "Expected atomic baseline publication failure"
    exit 1
fi
cmp "$baseline" "$work/previous.json"
test "$(find "$work/reports" -mindepth 1 -maxdepth 1 -type d ! -name '.scout-stage-*' | wc -l | tr -d ' ')" -eq 1

"$KUJO_BIN" run scout.kujo -- tests/fixtures/publication -o "$work/reports" --write-baseline --baseline "$baseline_abs" > "$work/success.log"
run_dir="$(awk -F': ' '/^Output: /{print $2}' "$work/success.log" | tail -n 1)"
test -f "$run_dir/scan_manifest.json"
jq -e '.artifacts.intelligence == "intelligence.json"' "$run_dir/scan_manifest.json" >/dev/null
jq -e '(.fingerprints | length) > 0' "$baseline" >/dev/null
if find "$work/baseline" -maxdepth 1 -name '*.tmp' | grep -q .; then
    echo "Atomic baseline writer left temporary data"
    exit 1
fi

"$KUJO_BIN" run scout.kujo -- tests/fixtures/publication -o "$work/reports" --quick > "$work/concurrent-a.log" &
first_pid=$!
"$KUJO_BIN" run scout.kujo -- tests/fixtures/publication -o "$work/reports" --quick > "$work/concurrent-b.log" &
second_pid=$!
wait "$first_pid"
wait "$second_pid"
first_dir="$(awk -F': ' '/^Output: /{print $2}' "$work/concurrent-a.log" | tail -n 1)"
second_dir="$(awk -F': ' '/^Output: /{print $2}' "$work/concurrent-b.log" | tail -n 1)"
test "$first_dir" != "$second_dir"
test -f "$first_dir/scan_manifest.json"
test -f "$second_dir/scan_manifest.json"
echo "Staged report publication and atomic baseline recovery passed"
