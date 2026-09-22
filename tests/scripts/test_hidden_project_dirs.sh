#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"
cd "$REPO_ROOT"

mkdir -p tests/tmp/reports
"$KUJO_BIN" run scout.kujo -- tests/fixtures/hidden-scan -o tests/tmp/reports > tests/tmp/hidden-project-dirs.log
output_dir="$(awk -F': ' '/^Output: /{print $2}' tests/tmp/hidden-project-dirs.log | tail -n 1)"
jq -e '.metrics.total_files == 2 and ([.dependencies[].module] | index("json") != null and index("pathlib") != null)' "$output_dir/intelligence.json" >/dev/null
grep -q 'check.py' "$output_dir/FILE_TREE.md"
grep -q 'source.py' "$output_dir/FILE_TREE.md"

echo "Hidden project directories and external output-name collision passed"
