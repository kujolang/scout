#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"
cd "$REPO_ROOT"

work="$REPO_ROOT/tests/tmp/rooted-source-read"
rm -rf "$work"
mkdir -p "$work/target/safe" "$work/target-adjacent" "$work/outside" "$work/reports"
printf 'import pathlib\n' > "$work/target/safe/note.py"
printf 'import outside_secret\n' > "$work/outside/note.py"
printf 'import outside_secret\n' > "$work/target-adjacent/note.py"
ln -s safe "$work/target/inside-dir"
ln -s safe/note.py "$work/target/inside-file.py"
ln -s "$work/target/safe/note.py" "$work/target/absolute-inside.py"
ln -s "$work/outside/note.py" "$work/target/outside-file.py"
ln -s "$work/target-adjacent/note.py" "$work/target/adjacent-file.py"

"$KUJO_BIN" run scout.kujo -- "$work/target" -o "$work/reports" > "$work/control.log"
run_dir="$(awk -F': ' '/^Output: /{print $2}' "$work/control.log" | tail -n 1)"
jq -e '([.dependencies[].module] | index("pathlib") != null and index("outside_secret") == null) and ([.parse_errors[].error] | index("read_failed") == null)' "$run_dir/intelligence.json" >/dev/null
grep -q 'inside-dir' "$run_dir/FILE_TREE.md"
grep -q 'inside-file.py' "$run_dir/FILE_TREE.md"
grep -q 'absolute-inside.py' "$run_dir/FILE_TREE.md"

# A caller may set a character limit above 2 MiB; the rooted API must not
# silently introduce an 8 MiB request ceiling for otherwise small files.
printf '{"scan":{"max_file_size":2097153},"output":{"default_dir":"%s"}}\n' "$work/reports" > "$work/config.json"
(cd "$work" && "$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$work/target" > "$work/large-limit.log")
run_dir="$(awk -F': ' '/^Output: /{print $2}' "$work/large-limit.log" | tail -n 1)"
jq -e '([.dependencies[].module] | index("pathlib") != null) and ([.parse_errors[].error] | index("read_failed") == null)' "$run_dir/intelligence.json" >/dev/null

mkdir -p "$work/target/live"
cp "$work/target/safe/note.py" "$work/target/live/note.py"
(
  while :; do
    if mv "$work/target/live" "$work/target/parked" 2>/dev/null; then
      ln -s "$work/outside" "$work/target/live" 2>/dev/null || true
      unlink "$work/target/live" 2>/dev/null || true
      mv "$work/target/parked" "$work/target/live" 2>/dev/null || true
    fi
  done
) &
attacker_pid=$!
trap 'kill "$attacker_pid" 2>/dev/null || true; wait "$attacker_pid" 2>/dev/null || true' EXIT

for _ in 1 2 3 4 5 6; do
  "$KUJO_BIN" run scout.kujo -- "$work/target" -o "$work/reports" > "$work/race.log"
done
kill "$attacker_pid" 2>/dev/null || true
wait "$attacker_pid" 2>/dev/null || true
trap - EXIT

if grep -R -q 'outside_secret' "$work/reports"; then
  echo 'Rooted source read disclosed outside-root content' >&2
  exit 1
fi
echo 'Rooted prefix reads preserve in-root aliases and resist symlink swaps'
