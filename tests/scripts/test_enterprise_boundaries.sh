#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

case_root="$REPO_ROOT/tests/tmp/enterprise-boundaries"
mkdir -p "$case_root/target" "$case_root/outside" "$case_root/results"
python3 - "$case_root" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
target = root / "target"
(target / "normal.js").write_text("app.get('/safe')\n", encoding="utf-8")
(target / "name\n## injected.md").write_text("safe\n", encoding="utf-8")
(target / "package.json").write_text(json.dumps({"dependencies": {"evil\n## forged|`": "1"}}), encoding="utf-8")
(root / "outside" / "baseline.json").write_text('{"fingerprints": []}\n', encoding="utf-8")
(root / "outside" / "ignore").write_text("*.js\n", encoding="utf-8")
(root / "outside" / "empty-ignore").write_text("", encoding="utf-8")
PY

"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" -- "$case_root/target" -o "$case_root/results" -d 3 --strict >/dev/null
report_dir="$(find "$case_root/results" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
python3 - "$report_dir" <<'PY'
import json, pathlib, sys
report = pathlib.Path(sys.argv[1])
readme = (report / "README.md").read_text()
tree = (report / "FILE_TREE.md").read_text()
agents = (report / "AGENTS.md").read_text()
assert "\n## forged" not in readme
assert "\n## injected" not in tree
assert "evil ## forged&#124;'" in readme
assert "name ## injected.md" in tree
assert "Repository-derived route details are intentionally kept" in agents
assert "/safe" not in agents
data = json.loads((report / "intelligence.json").read_text())
assert any(item["module"] == "evil\n## forged|`" for item in data["dependencies"])
PY

ln -s "$case_root/outside/baseline.json" "$case_root/target/scout-baseline.json"
if "$KUJO_BIN" run "$REPO_ROOT/scout.kujo" -- "$case_root/target" -o "$case_root/baseline-results" --quick >"$case_root/baseline.log" 2>&1; then
	echo "Expected an outside-root baseline symlink to fail"
	exit 1
fi
grep -q "baseline path must stay within the scan target" "$case_root/baseline.log"
unlink "$case_root/target/scout-baseline.json"

ln -s "$case_root/outside/ignore" "$case_root/target/.scoutignore"
if "$KUJO_BIN" run "$REPO_ROOT/scout.kujo" -- "$case_root/target" -o "$case_root/ignore-results" --quick >"$case_root/ignore.log" 2>&1; then
	echo "Expected an outside-root ignore symlink to fail"
	exit 1
fi
grep -q "ignore file path must stay within the scan target" "$case_root/ignore.log"
unlink "$case_root/target/.scoutignore"

mkdir -p "$case_root/limited-cwd"
cat >"$case_root/limited-cwd/config.json" <<'JSON'
{"scan":{"max_entries":1}}
JSON
if (cd "$case_root/limited-cwd" && "$KUJO_BIN" run "$REPO_ROOT/scout.kujo" -- "$case_root/target" -o "$case_root/limited-results" --quick >"$case_root/limit.log" 2>&1); then
	echo "Expected a configured aggregate entry limit to fail closed"
	exit 1
fi
grep -q "scan entry limit exceeded: 1" "$case_root/limit.log"
grep -q "\[SCOUT-LIMIT-ENTRIES\]" "$case_root/limit.log"

mkdir -p "$case_root/diagnostic-target" "$case_root/code-limit-cwd" "$case_root/byte-limit-cwd" "$case_root/result-limit-cwd" "$case_root/ignore-limit-cwd"
printf "@app.get('/one')\n@app.get('/two')\n" >"$case_root/diagnostic-target/routes.py"
printf "safe\n" >"$case_root/diagnostic-target/other.py"
printf '{"scan":{"max_code_files":1}}\n' >"$case_root/code-limit-cwd/config.json"
printf '{"scan":{"max_total_analyzed_bytes":1}}\n' >"$case_root/byte-limit-cwd/config.json"
printf '{"scan":{"max_analysis_results":1}}\n' >"$case_root/result-limit-cwd/config.json"
printf '{"scan":{"max_ignore_rules":1}}\n' >"$case_root/ignore-limit-cwd/config.json"
printf "*.none\n*.also-none\n" >"$case_root/diagnostic-target/.scoutignore"

assert_limit_code() {
	local working_dir="$1"
	local code="$2"
	local output_name="$3"
	shift 3
	if (cd "$working_dir" && "$KUJO_BIN" run "$REPO_ROOT/scout.kujo" -- "$case_root/diagnostic-target" -o "$case_root/$output_name" --quick "$@" >"$case_root/$output_name.log" 2>&1); then
		echo "Expected resource limit $code to fail closed"
		exit 1
	fi
	grep -q "\[$code\]" "$case_root/$output_name.log"
}

assert_limit_code "$case_root/code-limit-cwd" SCOUT-LIMIT-CODE-FILES code-limit --ignore-file "$case_root/outside/empty-ignore"
assert_limit_code "$case_root/byte-limit-cwd" SCOUT-LIMIT-ANALYZED-BYTES byte-limit --ignore-file "$case_root/outside/empty-ignore"
assert_limit_code "$case_root/result-limit-cwd" SCOUT-LIMIT-ROUTES result-limit --skip-deps --skip-security --ignore-file "$case_root/outside/empty-ignore"
assert_limit_code "$case_root/ignore-limit-cwd" SCOUT-LIMIT-IGNORE-RULES ignore-limit

"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" -- "$case_root/target" \
	-o "$case_root/absolute-results" \
	--baseline "$case_root/outside/baseline.json" \
	--ignore-file "$case_root/outside/ignore" \
	--quick >/dev/null

echo "Enterprise input, output, and resource boundary tests passed"
