#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/arc001"
OUT_ROOT="$REPO_ROOT/tests/tmp/feat006-output"
METADATA_SCHEMA_PATH="$REPO_ROOT/tests/fixtures/schemas/kennel.metadata.schema.json"
SCHEMA_VALIDATOR="$REPO_ROOT/tests/scripts/validate_json_schema.py"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT"

"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$FIXTURE_DIR" -o "$OUT_ROOT" -d 3 --kennel-index --kennel-metadata > "$OUT_ROOT/run.log"
out_dir="$(find "$OUT_ROOT" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

if [[ -z "$out_dir" ]]; then
	echo "No output directory generated"
	exit 1
fi

meta_path="$out_dir/packages/arc001.json"
index_path="$out_dir/index.json"

for p in "$meta_path" "$index_path"; do
	if [[ ! -f "$p" ]]; then
		echo "Missing expected Kennel artifact: $p"
		exit 1
	fi
done

python3 "$SCHEMA_VALIDATOR" --schema "$METADATA_SCHEMA_PATH" --instance "$meta_path"

if ! jq -e 'keys | sort == ["description","latest","name","repository","versions"]' "$meta_path" >/dev/null; then
	echo "Metadata top-level keys do not match expected contract fields"
	exit 1
fi

if [[ "$(jq -r '.name' "$meta_path")" != "arc001" ]]; then
	echo "Expected metadata name to match package slug"
	exit 1
fi

if [[ "$(jq -r '.latest' "$meta_path")" == "" ]]; then
	echo "Expected metadata latest to be non-empty"
	exit 1
fi

if [[ "$(jq -r '.repository' "$meta_path")" == "" ]]; then
	echo "Expected metadata repository to be non-empty"
	exit 1
fi

if [[ "$(jq '.versions | length' "$meta_path")" -lt 1 ]]; then
	echo "Expected at least one metadata version entry"
	exit 1
fi

if ! jq -e '.versions[0] | keys | sort == ["published_at","ref","source","version"]' "$meta_path" >/dev/null; then
	echo "Metadata version keys do not match expected contract fields"
	exit 1
fi

if ! jq -e '.versions[0].source | startswith("scout:")' "$meta_path" >/dev/null; then
	echo "Expected metadata version source to use scout: prefix"
	exit 1
fi

if [[ "$(jq -r '.latest' "$meta_path")" != "$(jq -r '.versions[0].version' "$meta_path")" ]]; then
	echo "Expected metadata latest to match first version"
	exit 1
fi

if [[ "$(jq -r '.packages[0].metadata_path' "$index_path")" != "packages/arc001.json" ]]; then
	echo "Expected index metadata_path to point to package metadata document"
	exit 1
fi

echo "FEAT-006 Kennel metadata regression test passed"