#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/feat009_security_redaction"
OUT_ROOT="$REPO_ROOT/tests/tmp/feat009-output"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT"

"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$FIXTURE_DIR" -o "$OUT_ROOT" -d 2 --skip-deps --skip-routes --security-export sarif --security-export jsonl > "$OUT_ROOT/run.log"
out_dir="$(find "$OUT_ROOT" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

if [[ -z "$out_dir" ]]; then
	echo "No output directory generated"
	exit 1
fi

json_path="$out_dir/intelligence.json"
sarif_path="$out_dir/security.sarif"
jsonl_path="$out_dir/security.jsonl"
report_path="$out_dir/README.md"

for target_path in "$json_path" "$sarif_path" "$jsonl_path" "$report_path"; do
	if [[ ! -f "$target_path" ]]; then
		echo "Missing expected output file: $target_path"
		exit 1
	fi
done

for leaked in \
	"feat009-password-should-not-leak" \
	"feat009-api-key-should-not-leak" \
	"feat009-private-key-should-not-leak"; do
	if grep -R -Fq "$leaked" "$out_dir"; then
		echo "Sensitive value leaked into Scout outputs: $leaked"
		exit 1
	fi
done

if [[ "$(jq '[.security_findings[] | select(.label == "Hardcoded credential")] | length' "$json_path")" -lt 2 ]]; then
	echo "Expected uppercase credential and API key findings"
	exit 1
fi

if [[ "$(jq '[.security_findings[] | select(.label == "Embedded private key")] | length' "$json_path")" -lt 1 ]]; then
	echo "Expected private key material finding"
	exit 1
fi

if [[ "$(jq '[.security_findings[] | select(.label == "Dangerous code execution function")] | length' "$json_path")" -ne 1 ]]; then
	echo "Expected exactly one real dangerous-call finding"
	exit 1
fi

if [[ "$(jq '[.security_findings[] | select(.snippet | contains("<redacted>") or contains("<redacted private key material>"))] | length' "$json_path")" -lt 3 ]]; then
	echo "Expected sensitive snippets to be redacted"
	exit 1
fi

if grep -Fq 'literal_only = "eval("' "$json_path" || grep -Fq 'const harmless = "system("' "$json_path"; then
	echo "Quoted dangerous-call literals should not be reported"
	exit 1
fi

echo "FEAT-009 security redaction regression test passed"
