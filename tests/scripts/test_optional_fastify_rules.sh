#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/lib.sh"
resolve_kujo_bin "$REPO_ROOT"
cd "$REPO_ROOT"

work="tests/tmp/optional-fastify"
rm -rf "$work"
mkdir -p "$work"
target="tests/fixtures/optional-rules/fastify"
"$KUJO_BIN" run scout.kujo -- "$target" -o "$work" --quick > "$work/default.log"
default_dir="$(awk -F': ' '/^Output: /{print $2}' "$work/default.log" | tail -n 1)"
jq -e '.routes == [{"method":"GET","path":"/health","source":"routes.ts"}]' "$default_dir/intelligence.json" >/dev/null

"$KUJO_BIN" run scout.kujo -- "$target" -o "$work" --quick --rule fastify-object --rule fastify-object > "$work/opt-in.log"
rule_dir="$(awk -F': ' '/^Output: /{print $2}' "$work/opt-in.log" | tail -n 1)"
jq -e '.flags.optional_rules == ["fastify-object"] and (.routes | length == 4) and ([.routes[] | .method + " " + .path] | sort) == ["DELETE /users/:id","GET /health","GET /status","POST /users"]' "$rule_dir/intelligence.json" >/dev/null

printf '{"analysis":{"optional_rules":["fastify-object"]},"output":{"default_dir":"%s"}}\n' "$REPO_ROOT/$work" > "$work/config.json"
(cd "$work" && "$KUJO_BIN" run "$REPO_ROOT/scout.kujo" "$REPO_ROOT/$target" > "$REPO_ROOT/$work/config.log")
config_dir="$(awk -F': ' '/^Output: /{print $2}' "$work/config.log" | tail -n 1)"
jq -e '.routes | length == 4' "$config_dir/intelligence.json" >/dev/null

set +e
"$KUJO_BIN" run scout.kujo -- "$target" --rule unknown-rule > "$work/invalid.log" 2>&1
status=$?
set -e
test "$status" -ne 0
grep -q 'invalid optional rule' "$work/invalid.log"
echo "Fastify opt-in route precision, config, and default contracts passed"
