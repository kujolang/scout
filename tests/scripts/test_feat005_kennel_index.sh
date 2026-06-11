#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/arc001"
OUT_ROOT="$REPO_ROOT/tests/tmp/feat005-output"
INDEX_SCHEMA_PATH="$REPO_ROOT/tests/fixtures/schemas/kennel.index.schema.json"
SCHEMA_VALIDATOR="$REPO_ROOT/tests/scripts/validate_json_schema.py"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT"

"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$FIXTURE_DIR" -o "$OUT_ROOT" -d 3 --kennel-index > "$OUT_ROOT/run.log"
out_dir="$(find "$OUT_ROOT" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

if [[ -z "$out_dir" ]]; then
	echo "No output directory generated"
	exit 1
fi

index_path="$out_dir/index.json"
if [[ ! -f "$index_path" ]]; then
	echo "Missing index.json in kennel-index mode"
	exit 1
fi

python3 "$SCHEMA_VALIDATOR" --schema "$INDEX_SCHEMA_PATH" --instance "$index_path"

if ! jq -e 'keys | sort == ["generated_at","packages","schema_version"]' "$index_path" >/dev/null; then
	echo "index.json top-level keys do not match contract"
	exit 1
fi

if [[ "$(jq '.schema_version' "$index_path")" -ne 1 ]]; then
	echo "Expected schema_version=1"
	exit 1
fi

if [[ "$(jq '.packages | length' "$index_path")" -lt 1 ]]; then
	echo "Expected at least one package entry"
	exit 1
fi

if ! jq -e '.packages[0] | keys | sort == ["latest","metadata_path","name","versions"]' "$index_path" >/dev/null; then
	echo "Package summary keys do not match contract"
	exit 1
fi

if [[ "$(jq -r '.packages[0].name' "$index_path")" != "arc001" ]]; then
	echo "Expected package name to match scanned slug (arc001)"
	exit 1
fi

if ! jq -e '.packages[0].metadata_path | test("^packages/.+\\.json$")' "$index_path" >/dev/null; then
	echo "metadata_path does not match contract pattern"
	exit 1
fi

if [[ "$(jq '.packages[0].versions | length' "$index_path")" -lt 1 ]]; then
	echo "Expected at least one version entry"
	exit 1
fi

if ! jq -e '.packages[0].versions[0] | keys | sort == ["ref","source","version"]' "$index_path" >/dev/null; then
	echo "Version summary keys do not match contract"
	exit 1
fi

if ! jq -e '.packages[0].versions[0].source | startswith("scout:")' "$index_path" >/dev/null; then
	echo "Expected version source to use scout: prefix"
	exit 1
fi

echo "FEAT-005 Kennel index regression test passed"