#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"

cd "$REPO_ROOT"
TARGET="tests/fixtures/arc001"
TMP_ROOT="tests/tmp/feat002_path_modes"

rm -rf "$TMP_ROOT"
mkdir -p "$TMP_ROOT"

"$KUJO_BIN" run scout.kujo "$TARGET" -o "$TMP_ROOT/relative" -d 3
REL_OUT="$(ls -td "$TMP_ROOT/relative"/* | head -n 1)"
REL_INTEL="$REL_OUT/intelligence.json"

REL_DEP_SOURCE="$(jq -r '.dependencies[0].source' "$REL_INTEL")"
REL_LARGEST_PATH="$(jq -r '.metrics.largest_files[0].path' "$REL_INTEL")"
REL_TARGET="$(jq -r '.target' "$REL_INTEL")"

if [[ "$REL_DEP_SOURCE" == /* ]]; then
  echo "Expected relative dependency source path in default mode; got: $REL_DEP_SOURCE"
  exit 1
fi

if [[ "$REL_LARGEST_PATH" == /* ]]; then
  echo "Expected relative largest-file path in default mode; got: $REL_LARGEST_PATH"
  exit 1
fi

if [[ "$REL_TARGET" == /* ]]; then
  echo "Expected relative target field in default mode; got: $REL_TARGET"
  exit 1
fi

"$KUJO_BIN" run scout.kujo "$TARGET" -o "$TMP_ROOT/absolute" -d 3 --path-mode absolute
ABS_OUT="$(ls -td "$TMP_ROOT/absolute"/* | head -n 1)"
ABS_INTEL="$ABS_OUT/intelligence.json"

ABS_DEP_SOURCE="$(jq -r '.dependencies[0].source' "$ABS_INTEL")"
ABS_LARGEST_PATH="$(jq -r '.metrics.largest_files[0].path' "$ABS_INTEL")"
ABS_TARGET="$(jq -r '.target' "$ABS_INTEL")"

if [[ "$ABS_DEP_SOURCE" != /* ]]; then
  echo "Expected absolute dependency source path in absolute mode; got: $ABS_DEP_SOURCE"
  exit 1
fi

if [[ "$ABS_LARGEST_PATH" != /* ]]; then
  echo "Expected absolute largest-file path in absolute mode; got: $ABS_LARGEST_PATH"
  exit 1
fi

if [[ "$ABS_TARGET" != /* ]]; then
  echo "Expected absolute target field in absolute mode; got: $ABS_TARGET"
  exit 1
fi

echo "FEAT-002 path mode regression test passed"
