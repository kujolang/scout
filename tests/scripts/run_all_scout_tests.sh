#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

cd "$REPO_ROOT"
rm -rf tests/tmp
mkdir -p tests/tmp

tests=(
	tests/scripts/test_arc001_languages.sh
	tests/scripts/test_arc002_slug_sanitization.sh
	tests/scripts/test_arc003_config_precedence.sh
	tests/scripts/test_arc006_largest_files_topk.sh
	tests/scripts/test_arc007_deterministic_order.sh
	tests/scripts/test_sec001_self_match.sh
	tests/scripts/test_sec002_exec_precision.sh
	tests/scripts/test_feat001_include_exclude.sh
	tests/scripts/test_feat002_path_modes.sh
	tests/scripts/test_feat003_security_exports.sh
	tests/scripts/test_feat004_baseline_suppression.sh
	tests/scripts/test_feat005_kennel_index.sh
	tests/scripts/test_feat006_kennel_metadata.sh
	tests/scripts/test_feat007_scan_manifest.sh
	tests/scripts/test_feat008_symlink_boundary.sh
	tests/scripts/test_test001_fixture_suite.sh
	tests/scripts/test_test002_route_matrix.sh
	tests/scripts/test_test003_security_matrix.sh
	tests/scripts/test_test004_cli_matrix.sh
	tests/scripts/test_test005_golden_snapshots.sh
	tests/scripts/test_test006_security_rule_coverage.sh
)

if [[ "${SCOUT_SKIP_SLOW:-0}" == "1" ]]; then
	filtered=()
	for test_script in "${tests[@]}"; do
		if [[ "$test_script" == "tests/scripts/test_arc002_slug_sanitization.sh" ]]; then
			continue
		fi
		filtered+=("$test_script")
	done
	tests=("${filtered[@]}")
fi

for test_script in "${tests[@]}"; do
	echo "RUN $test_script"
	"$test_script"
done

echo "All Scout tests passed"
