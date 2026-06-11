#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/sec002"
OUT_ROOT="$REPO_ROOT/tests/tmp/feat007-output"
BASELINE_PATH="$FIXTURE_DIR/generated-baseline.json"
MANIFEST_SCHEMA_PATH="$REPO_ROOT/tests/fixtures/schemas/scan_manifest.schema.json"
SCHEMA_VALIDATOR="$REPO_ROOT/tests/scripts/validate_json_schema.py"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

cleanup() {
	rm -f "$BASELINE_PATH"
}
trap cleanup EXIT

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT"

"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$FIXTURE_DIR" -o "$OUT_ROOT" -d 3 --security-export sarif --security-export jsonl --kennel-index --kennel-metadata --write-baseline --baseline generated-baseline.json > "$OUT_ROOT/run.log"
out_dir="$(find "$OUT_ROOT" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

if [[ -z "$out_dir" ]]; then
	echo "No output directory generated"
	exit 1
fi

manifest_path="$out_dir/scan_manifest.json"
if [[ ! -f "$manifest_path" ]]; then
	echo "Missing scan_manifest.json"
	exit 1
fi

python3 "$SCHEMA_VALIDATOR" --schema "$MANIFEST_SCHEMA_PATH" --instance "$manifest_path"

if ! jq -e 'keys | sort == ["artifacts","generated_at","output","schema_version","target","tool"]' "$manifest_path" >/dev/null; then
	echo "scan_manifest top-level keys do not match expected schema"
	exit 1
fi

if [[ "$(jq '.schema_version' "$manifest_path")" -ne 1 ]]; then
	echo "Expected scan_manifest schema_version=1"
	exit 1
fi

if ! jq -e '.tool | keys | sort == ["name","version"]' "$manifest_path" >/dev/null; then
	echo "Expected scan_manifest.tool to include name and version"
	exit 1
fi

required_keys=(file_tree report llms agents checklist intelligence security_sarif security_jsonl kennel_index kennel_metadata)
for key in "${required_keys[@]}"; do
	artifact_rel="$(jq -r ".artifacts.${key} // \"\"" "$manifest_path")"
	if [[ -z "$artifact_rel" || "$artifact_rel" == "null" ]]; then
		echo "Missing artifact pointer for key: $key"
		exit 1
	fi
	if [[ ! -f "$out_dir/$artifact_rel" ]]; then
		echo "Artifact path from manifest does not exist: $artifact_rel"
		exit 1
	fi
done

if [[ ! -f "$BASELINE_PATH" ]]; then
	echo "Expected baseline file to be written when --write-baseline is set"
	exit 1
fi

echo "FEAT-007 scan manifest regression test passed"