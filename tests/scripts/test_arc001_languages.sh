#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/arc001"
OUT_ROOT="$REPO_ROOT/tests/tmp/arc001-output"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT"

"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$FIXTURE_DIR" -o "$OUT_ROOT" -d 4 > "$OUT_ROOT/run.log"

latest_dir="$(ls -1 "$OUT_ROOT" | head -n 1)"
if [[ -z "$latest_dir" ]]; then
	echo "No output directory generated"
	exit 1
fi

json_path="$OUT_ROOT/$latest_dir/intelligence.json"
if [[ ! -f "$json_path" ]]; then
	echo "Missing intelligence.json"
	exit 1
fi

languages_len="$(jq '.metrics.languages | length' "$json_path")"
if [[ "$languages_len" -lt 2 ]]; then
	echo "Expected at least 2 detected languages, got $languages_len"
	exit 1
fi

python_count="$(jq '.metrics.languages.Python // 0' "$json_path")"
js_count="$(jq '.metrics.languages.JavaScript // 0' "$json_path")"
if [[ "$python_count" -lt 1 || "$js_count" -lt 1 ]]; then
	echo "Expected Python and JavaScript counts >= 1; got Python=$python_count JS=$js_count"
	exit 1
fi

suffix_fixture="$OUT_ROOT/suffix-fixture"
mkdir -p "$suffix_fixture/nested"
printf 'import pathlib\n' > "$suffix_fixture/.py"
printf 'import sys\n' > "$suffix_fixture/nested/multi.part..py"
printf 'import ignored_case\n' > "$suffix_fixture/source.PY"
printf 'import ignored_trailing_dot\n' > "$suffix_fixture/source.py."
printf 'import ignored_binary\n' > "$suffix_fixture/source.py.png"
printf 'gem "rack"\n' > "$suffix_fixture/Gemfile"
printf 'requests==2.32.0\n' > "$suffix_fixture/requirements-dev.txt"

for profile in full minimal; do
	"$KUJO_BIN" run "$REPO_ROOT/scout.kujo" -- "$suffix_fixture" \
		-o "$OUT_ROOT/$profile" --output-profile "$profile" --strict > "$OUT_ROOT/$profile.log"
	report="$(find "$OUT_ROOT/$profile" -mindepth 1 -maxdepth 1 -type d)"
	jq -e '
		.metrics.total_files == 4 and .metrics.languages.Python == 2 and
		[.dependencies[].module] == ["pathlib", "rack", "requests", "sys"]
	' "$report/intelligence.json" >/dev/null
	if [[ "$profile" == full ]]; then
		full_report="$report"
		grep -qE '^    - \[F\] multi\.part\.\.py \(Python,' "$report/FILE_TREE.md"
		grep -qE '^  - \[F\] source\.PY \(Unknown,' "$report/FILE_TREE.md"
	else
		test ! -e "$report/FILE_TREE.md"
		diff -u "$full_report/README.md" "$report/README.md"
	fi
done

echo "ARC-001 language metrics regression test passed"
