#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/arc003"
CONFIG_PATH="$REPO_ROOT/config.json"
BACKUP_PATH="$REPO_ROOT/config.json.arc003.bak"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

cp "$CONFIG_PATH" "$BACKUP_PATH"
restore_config() {
	if [[ -f "$BACKUP_PATH" ]]; then
		mv "$BACKUP_PATH" "$CONFIG_PATH"
	fi
}
trap restore_config EXIT

cat > "$CONFIG_PATH" <<'JSON'
{
  "scan": {
    "default_max_depth": 1,
    "max_file_size": 500000,
    "ignored_dirs": [".git", "node_modules"]
  },
  "output": {
    "default_dir": "./tests/tmp/arc003-default-out"
  },
  "analysis": {
    "dependencies": false,
    "routes": false,
    "security": false,
    "metrics": true
  }
}
JSON

rm -rf "$REPO_ROOT/tests/tmp/arc003-default-out" "$REPO_ROOT/tests/tmp/arc003-cli-out"
mkdir -p "$REPO_ROOT/tests/tmp/arc003-default-out" "$REPO_ROOT/tests/tmp/arc003-cli-out"

"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$FIXTURE_DIR" > "$REPO_ROOT/tests/tmp/arc003-default.log"
default_out_dir="$(awk -F': ' '/^Output: /{print $2}' "$REPO_ROOT/tests/tmp/arc003-default.log" | tail -n 1)"
if [[ "$default_out_dir" != ./tests/tmp/arc003-default-out/* ]]; then
	echo "Expected config output.default_dir to be used; got: $default_out_dir"
	exit 1
fi

default_json="$default_out_dir/intelligence.json"
if [[ ! -f "$default_json" ]]; then
	echo "Missing intelligence.json for default config run"
	exit 1
fi

if [[ "$(jq '.flags.max_depth' "$default_json")" -ne 1 ]]; then
	echo "Expected config default_max_depth=1"
	exit 1
fi

if [[ "$(jq '.metrics.languages.JavaScript // 0' "$default_json")" -ne 0 ]]; then
	echo "Expected JavaScript file to be excluded by config default depth"
	exit 1
fi

if [[ "$(jq '.flags.skip_security' "$default_json")" != "true" ]]; then
	echo "Expected security analysis to be skipped from config"
	exit 1
fi

"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$FIXTURE_DIR" -o ./tests/tmp/arc003-cli-out -d 4 > "$REPO_ROOT/tests/tmp/arc003-cli.log"
cli_out_dir="$(awk -F': ' '/^Output: /{print $2}' "$REPO_ROOT/tests/tmp/arc003-cli.log" | tail -n 1)"
if [[ "$cli_out_dir" != ./tests/tmp/arc003-cli-out/* ]]; then
	echo "Expected CLI -o to override config output.default_dir; got: $cli_out_dir"
	exit 1
fi

cli_json="$cli_out_dir/intelligence.json"
if [[ ! -f "$cli_json" ]]; then
	echo "Missing intelligence.json for CLI override run"
	exit 1
fi

if [[ "$(jq '.flags.max_depth' "$cli_json")" -ne 4 ]]; then
	echo "Expected CLI -d=4 to override config default_max_depth"
	exit 1
fi

if [[ "$(jq '.metrics.languages.JavaScript // 0' "$cli_json")" -lt 1 ]]; then
	echo "Expected JavaScript file to be included with deeper CLI depth"
	exit 1
fi

cat > "$CONFIG_PATH" <<'JSON'
{
  "scan": {
    "default_max_depth": 4,
    "max_file_size": 500000,
    "ignored_dirs": [".git", "node_modules"]
  },
  "output": {
    "default_dir": "./tests/tmp/arc003-metrics-off"
  },
  "analysis": {
    "dependencies": true,
    "routes": true,
    "security": true,
    "metrics": false
  }
}
JSON

rm -rf "$REPO_ROOT/tests/tmp/arc003-metrics-off"
mkdir -p "$REPO_ROOT/tests/tmp/arc003-metrics-off"

"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$FIXTURE_DIR" > "$REPO_ROOT/tests/tmp/arc003-metrics-off.log"
metrics_off_dir="$(awk -F': ' '/^Output: /{print $2}' "$REPO_ROOT/tests/tmp/arc003-metrics-off.log" | tail -n 1)"
metrics_off_json="$metrics_off_dir/intelligence.json"

if [[ ! -f "$metrics_off_json" ]]; then
	echo "Missing intelligence.json for metrics-disabled config run"
	exit 1
fi

if [[ "$(jq -r '.flags.metrics_enabled' "$metrics_off_json")" != "false" ]]; then
	echo "Expected flags.metrics_enabled=false when analysis.metrics=false"
	exit 1
fi

if [[ "$(jq '.metrics.total_files' "$metrics_off_json")" -ne 0 ]]; then
	echo "Expected metrics.total_files=0 when metrics are disabled"
	exit 1
fi

if [[ "$(jq '.metrics.total_lines' "$metrics_off_json")" -ne 0 ]]; then
	echo "Expected metrics.total_lines=0 when metrics are disabled"
	exit 1
fi

if [[ "$(jq '.metrics.total_size' "$metrics_off_json")" -ne 0 ]]; then
	echo "Expected metrics.total_size=0 when metrics are disabled"
	exit 1
fi

if [[ "$(jq '.metrics.languages | length' "$metrics_off_json")" -ne 0 ]]; then
	echo "Expected metrics.languages to be empty when metrics are disabled"
	exit 1
fi

if [[ "$(jq '.metrics.largest_files | length' "$metrics_off_json")" -ne 0 ]]; then
	echo "Expected metrics.largest_files to be empty when metrics are disabled"
	exit 1
fi

echo "ARC-003 config precedence regression test passed"
