#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_ROOT="/tmp/scout_phase10_symlink_fix"
PROJECT_DIR="$FIXTURE_ROOT/project"
EXTERNAL_DIR="$FIXTURE_ROOT/external_dir"
OUT_ROOT="$FIXTURE_ROOT/out"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

rm -rf "$FIXTURE_ROOT"
mkdir -p "$PROJECT_DIR/src" "$PROJECT_DIR/node_modules/ignored" "$PROJECT_DIR/vendor" "$EXTERNAL_DIR" "$OUT_ROOT"

cat > "$PROJECT_DIR/README.md" <<'EOF'
# Scout Symlink Boundary Smoke

Safe local project.
EOF

cat > "$PROJECT_DIR/src/main.kujo" <<'EOF'
func main() {
  print("hello")
}
EOF

cat > "$PROJECT_DIR/src/secret.py" <<'EOF'
password = "phase10-placeholder-secret-inside-root"
token = "phase10-placeholder-token-inside-root"
EOF

cat > "$PROJECT_DIR/node_modules/ignored/pkg.js" <<'EOF'
console.log("ignored dependency")
EOF

cat > "$PROJECT_DIR/vendor/lib.go" <<'EOF'
package vendor
EOF

cat > "$PROJECT_DIR/.scoutignore" <<'EOF'
vendor/
EOF

cat > "$EXTERNAL_DIR/outside.md" <<'EOF'
# Outside root

API_KEY="phase10-placeholder-secret-outside-root"
TOKEN="phase10-placeholder-token-outside-root"
EOF

ln -s "$EXTERNAL_DIR" "$PROJECT_DIR/src/outside-link"

cd "$REPO_ROOT"

"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$PROJECT_DIR" -o "$OUT_ROOT/default" -d 3 --skip-deps --skip-routes --security-export sarif --security-export jsonl > "$OUT_ROOT/default.log"
out_dir="$(find "$OUT_ROOT/default" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

if [[ -z "$out_dir" ]]; then
	echo "No output directory generated for default run"
	exit 1
fi

json_path="$out_dir/intelligence.json"
tree_path="$out_dir/FILE_TREE.md"
llms_path="$out_dir/llms.txt"
agents_path="$out_dir/AGENTS.md"
checklist_path="$out_dir/CHECKLIST.md"
manifest_path="$out_dir/scan_manifest.json"
sarif_path="$out_dir/security.sarif"
jsonl_path="$out_dir/security.jsonl"
report_path="$out_dir/README.md"

for target_path in "$json_path" "$tree_path" "$llms_path" "$agents_path" "$checklist_path" "$manifest_path" "$sarif_path" "$jsonl_path" "$report_path"; do
	if [[ ! -f "$target_path" ]]; then
		echo "Missing expected output file: $target_path"
		exit 1
	fi
done

if grep -R -Fq "phase10-placeholder-secret-outside-root" "$out_dir"; then
	echo "Outside-root secret leaked into Scout outputs"
	exit 1
fi

if grep -R -Fq "phase10-placeholder-token-outside-root" "$out_dir"; then
	echo "Outside-root token leaked into Scout outputs"
	exit 1
fi

if grep -R -Fq "src/outside-link/outside.md" "$out_dir"; then
	echo "Outside-root symlink target path leaked into Scout outputs"
	exit 1
fi

if grep -Fq "outside-link" "$tree_path"; then
	echo "FILE_TREE.md unexpectedly included the outside-root symlink"
	exit 1
fi

if grep -Fq "node_modules/ignored/pkg.js" "$tree_path"; then
	echo "FILE_TREE.md unexpectedly included ignored node_modules content"
	exit 1
fi

if grep -Fq "vendor/lib.go" "$tree_path"; then
	echo "FILE_TREE.md unexpectedly included ignored vendor content"
	exit 1
fi

if [[ "$(jq '.security_findings | length' "$json_path")" -ne 2 ]]; then
	echo "Expected two inside-root security findings"
	exit 1
fi

if [[ "$(jq '[.security_findings[] | select(.file == "src/secret.py")] | length' "$json_path")" -ne 2 ]]; then
	echo "Expected the security findings to come from inside-root secret.py"
	exit 1
fi

if [[ "$(jq '[.security_findings[] | select(.file | contains("outside-link"))] | length' "$json_path")" -ne 0 ]]; then
	echo "Expected zero outside-root symlink findings in intelligence.json"
	exit 1
fi

if [[ "$(jq '[.metrics.largest_files[] | select(.path | contains("outside-link"))] | length' "$json_path")" -ne 0 ]]; then
	echo "Expected zero outside-root symlink files in largest_files"
	exit 1
fi

if grep -Fq "phase10-placeholder-secret-outside-root" "$sarif_path" || grep -Fq "phase10-placeholder-token-outside-root" "$sarif_path"; then
	echo "Outside-root secret leaked into SARIF export"
	exit 1
fi

if grep -Fq "phase10-placeholder-secret-outside-root" "$jsonl_path" || grep -Fq "phase10-placeholder-token-outside-root" "$jsonl_path"; then
	echo "Outside-root secret leaked into JSONL export"
	exit 1
fi

if ! grep -Fq "phase10-placeholder-secret-inside-root" "$sarif_path" || ! grep -Fq "phase10-placeholder-token-inside-root" "$sarif_path"; then
	echo "Expected inside-root secret findings in SARIF export"
	exit 1
fi

if ! grep -Fq "phase10-placeholder-secret-inside-root" "$jsonl_path" || ! grep -Fq "phase10-placeholder-token-inside-root" "$jsonl_path"; then
	echo "Expected inside-root secret findings in JSONL export"
	exit 1
fi

echo "FEAT-008 symlink boundary regression test passed"
