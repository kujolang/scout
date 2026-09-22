#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"
cd "$REPO_ROOT"

fixture="tests/tmp/bounded-read/target"
output="tests/tmp/bounded-read/output"
mkdir -p "$fixture" "$output"
printf 'import pathlib\n' > "$fixture/large.py"
dd if=/dev/zero bs=1048576 count=64 >> "$fixture/large.py" 2>/dev/null
"$KUJO_BIN" run scout.kujo -- "$fixture" -o "$output" > tests/tmp/bounded-read/scan.log
run_dir="$(awk -F': ' '/^Output: /{print $2}' tests/tmp/bounded-read/scan.log | tail -n 1)"
jq -e '.metrics.total_files == 1 and ([.dependencies[].module] | index("pathlib") != null) and ([.parse_errors[].error] | index("truncated_500000b") != null)' "$run_dir/intelligence.json" >/dev/null

"$KUJO_BIN" run scout.kujo -- tests/fixtures/bounded-read -o "$output" > tests/tmp/bounded-read/control.log
run_dir="$(awk -F': ' '/^Output: /{print $2}' tests/tmp/bounded-read/control.log | tail -n 1)"
jq -e '.metrics.total_files == 1 and ([.dependencies[].module] | index("os") != null) and (.parse_errors | length == 0)' "$run_dir/intelligence.json" >/dev/null
echo "Bounded source read and unchanged small-file control passed"

utf8_target="tests/tmp/bounded-read/utf8"
mkdir -p "$utf8_target"
awk 'BEGIN {printf "import json\n"; for (i = 0; i < 300000; i++) printf "é"; printf "\n"}' > "$utf8_target/multibyte.py"
"$KUJO_BIN" run scout.kujo -- "$utf8_target" -o "$output" > tests/tmp/bounded-read/utf8.log
run_dir="$(awk -F': ' '/^Output: /{print $2}' tests/tmp/bounded-read/utf8.log | tail -n 1)"
jq -e '.metrics.total_files == 1 and ([.dependencies[].module] | index("json") != null) and (.parse_errors | length == 0)' "$run_dir/intelligence.json" >/dev/null

awk 'BEGIN {printf "import pathlib\n"; for (i = 0; i < 500001; i++) printf "😀"; printf "\n"}' > "$utf8_target/multibyte.py"
"$KUJO_BIN" run scout.kujo -- "$utf8_target" -o "$output" > tests/tmp/bounded-read/utf8-cut.log
run_dir="$(awk -F': ' '/^Output: /{print $2}' tests/tmp/bounded-read/utf8-cut.log | tail -n 1)"
jq -e '.metrics.total_files == 1 and ([.dependencies[].module] | index("pathlib") != null) and ([.parse_errors[].error] | index("truncated_500000b") != null) and ([.parse_errors[].error] | index("read_failed") == null)' "$run_dir/intelligence.json" >/dev/null
echo "Unicode character limit and UTF-8 boundary passed"
