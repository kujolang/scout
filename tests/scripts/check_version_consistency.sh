#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT"

if [[ ! -f scout.kujo || ! -f config.json ]]; then
	echo "Missing required files for version check"
	exit 1
fi

scout_version="$(grep -E '^VERSION := "' scout.kujo | head -n 1 | cut -d '"' -f 2)"
config_version="$(jq -r '.tool.version' config.json)"
version_file="$(tr -d '\n' < VERSION)"
kujo_project_version="$(awk -F '"' '/^version = "/ {print $2; exit}' kujo.toml)"
kennel_project_version="$(awk -F '"' '/^version = "/ {print $2; exit}' kennel.toml)"
kujo_minimum="$(awk -F '"' '/^minimum_version = "/ {print $2; exit}' kujo.toml)"
kennel_minimum="$(awk -F '"' '/^minimum_version = "/ {print $2; exit}' kennel.toml)"

if [[ -z "$scout_version" ]]; then
	echo "Unable to parse VERSION from scout.kujo"
	exit 1
fi

if [[ "$config_version" == "null" || -z "$config_version" ]]; then
	echo "Unable to parse tool.version from config.json"
	exit 1
fi

if [[ "$scout_version" != "$config_version" ]]; then
	echo "Version mismatch: scout.kujo=$scout_version config.json=$config_version"
	exit 1
fi

if [[ "$scout_version" != "$version_file" || "$scout_version" != "$kujo_project_version" || "$scout_version" != "$kennel_project_version" ]]; then
	echo "Version mismatch among scout.kujo, config.json, VERSION, kujo.toml, and kennel.toml"
	exit 1
fi

if [[ "$kujo_minimum" != "1.5.0" || "$kennel_minimum" != "1.5.0" ]]; then
	echo "Minimum declared Kujo release must support read_binary_prefix_beneath (1.5.0)"
	exit 1
fi

ci_kujo_version="$(awk -F ' ' '/^[[:space:]]*KUJO_VERSION:/ {print $2; exit}' .github/workflows/repo-checks.yml)"
ci_kujo_sha256="$(awk -F ' ' '/^[[:space:]]*KUJO_LINUX_X64_SHA256:/ {print $2; exit}' .github/workflows/repo-checks.yml)"

if [[ "$ci_kujo_version" != "$kujo_minimum" ]]; then
	echo "CI Kujo release must match the declared minimum: ci=$ci_kujo_version minimum=$kujo_minimum"
	exit 1
fi

if [[ ! "$ci_kujo_sha256" =~ ^[0-9a-f]{64}$ ]]; then
	echo "CI Kujo release SHA-256 must be a lowercase 64-character digest"
	exit 1
fi

if grep -q 'SCOUT_CI_KUJO_REF' .github/workflows/repo-checks.yml; then
	echo "CI must use the published Kujo release archive, not the retired source pin"
	exit 1
fi

if [[ ! "$scout_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "Version is not semver-like x.y.z: $scout_version"
	exit 1
fi

if [[ ! -f CHANGELOG.md ]]; then
	echo "Missing CHANGELOG.md"
	exit 1
fi

if ! grep -q '^## \[Unreleased\]' CHANGELOG.md; then
	echo "CHANGELOG.md must contain an [Unreleased] section"
	exit 1
fi

echo "Version consistency check passed: $scout_version"
