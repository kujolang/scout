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
