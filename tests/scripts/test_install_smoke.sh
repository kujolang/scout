#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"
cd "$REPO_ROOT"

out="tests/tmp/install-smoke"
mkdir -p "$out"
"$KUJO_BIN" run scout.kujo -- tests/fixtures/arc001 -o "$out" --quick > "$out/run.log"
run_dir="$(awk -F': ' '/^Output: /{print $2}' "$out/run.log" | tail -n 1)"
jq -e '.tool.name == "scout" and .metrics.total_files == 2' "$run_dir/intelligence.json" >/dev/null
jq -e '.artifacts.report == "README.md" and .artifacts.intelligence == "intelligence.json"' "$run_dir/scan_manifest.json" >/dev/null
echo "Installed runtime quick-start smoke passed"
