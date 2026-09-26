#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"
cd "$REPO_ROOT"

receipt="tests/tmp/route-hotspot-profile.json"
python3 tests/scripts/profile_route_hotspot.py --kujo "$KUJO_BIN" --output "$receipt" --routes 64
jq -e '.output_equivalent == true and .routes == 64 and (.phases.array_rebuilding.elapsed_ms >= 0) and (.phases.sorting.elapsed_ms >= 0) and (.phases.full_scan.report_bytes > .phases.quick_scan.report_bytes)' "$receipt" >/dev/null
echo "Route hotspot profiling contract passed"
