#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/sec002"
OUT_ROOT="$REPO_ROOT/tests/tmp/feat003-output"
SARIF_SCHEMA_PATH="$REPO_ROOT/tests/fixtures/schemas/security.sarif.schema.json"
JSONL_SCHEMA_PATH="$REPO_ROOT/tests/fixtures/schemas/security.jsonl.entry.schema.json"
SCHEMA_VALIDATOR="$REPO_ROOT/tests/scripts/validate_json_schema.py"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT"

"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$FIXTURE_DIR" -o "$OUT_ROOT" -d 3 --security-export sarif --security-export jsonl > "$OUT_ROOT/run.log"
out_dir="$(find "$OUT_ROOT" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

if [[ -z "$out_dir" ]]; then
	echo "No output directory generated"
	exit 1
fi

json_path="$out_dir/intelligence.json"
sarif_path="$out_dir/security.sarif"
jsonl_path="$out_dir/security.jsonl"

for p in "$json_path" "$sarif_path" "$jsonl_path"; do
	if [[ ! -f "$p" ]]; then
		echo "Missing expected output file: $p"
		exit 1
	fi
done

python3 "$SCHEMA_VALIDATOR" --schema "$SARIF_SCHEMA_PATH" --instance "$sarif_path"
python3 "$SCHEMA_VALIDATOR" --schema "$JSONL_SCHEMA_PATH" --instance "$jsonl_path" --jsonl

if [[ "$(jq '.flags.security_exports | length' "$json_path")" -ne 2 ]]; then
	echo "Expected two enabled security export formats in intelligence flags"
	exit 1
fi

if [[ "$(jq -r '.["$schema"]' "$sarif_path")" != "https://json.schemastore.org/sarif-2.1.0.json" ]]; then
	echo "Unexpected SARIF schema URI"
	exit 1
fi

if [[ "$(jq -r '.version' "$sarif_path")" != "2.1.0" ]]; then
	echo "Unexpected SARIF version"
	exit 1
fi

if [[ "$(jq '.runs | length' "$sarif_path")" -ne 1 ]]; then
	echo "Expected exactly one SARIF run"
	exit 1
fi

if [[ "$(jq '.runs[0].tool.driver.rules | length' "$sarif_path")" -lt 1 ]]; then
	echo "Expected SARIF rules to be populated"
	exit 1
fi

if [[ "$(jq '.runs[0].results | length' "$sarif_path")" -ne 1 ]]; then
	echo "Expected one SARIF result from sec002 fixture"
	exit 1
fi

if [[ "$(jq -r '.runs[0].results[0].level' "$sarif_path")" != "error" ]]; then
	echo "Expected SARIF result level to map high severity to error"
	exit 1
fi

jsonl_count="$(jq -R -s 'split("\n") | map(select(length > 0) | fromjson) | length' "$jsonl_path")"
if [[ "$jsonl_count" -ne 1 ]]; then
	echo "Expected one JSONL finding record"
	exit 1
fi

jsonl_rule="$(jq -R -s 'split("\n") | map(select(length > 0) | fromjson)[0].rule_id' "$jsonl_path" | tr -d '"')"
if [[ "$jsonl_rule" != "SCOUT-DANGEROUS-EXECUTION" ]]; then
	echo "Unexpected JSONL rule id: $jsonl_rule"
	exit 1
fi

echo "FEAT-003 security export regression test passed"