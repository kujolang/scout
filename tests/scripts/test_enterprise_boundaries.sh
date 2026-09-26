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

"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" -- "$case_root/target" \
	-o "$case_root/absolute-results" \
	--baseline "$case_root/outside/baseline.json" \
	--ignore-file "$case_root/outside/ignore" \
	--quick >/dev/null

echo "Enterprise input, output, and resource boundary tests passed"
