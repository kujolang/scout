# Contributing to Scout

This guide documents the expected workflow for contributors and coding agents working on Scout.

## Core Rules

- Work checklist items in strict top-to-bottom order.
- Complete one item per loop.
- Keep diffs scoped to the current item only.
- Do not batch unrelated refactors.
- Update checklist state and work log in the same loop as code changes.

## One-Item-Per-Loop Protocol

1. Read, in order:
   - README.md
   - scout.kujo
   - config.json
   - docs/SCOUT_EVOLUTION_CHECKLIST.md
2. Pick the first unchecked actionable item.
3. Implement only that item.
4. Add or update tests for that item.
5. Run validation commands.
6. Mark the item checkbox (`- [ ]` to `- [x]`).
7. Append a work-log entry using the checklist template.
8. Commit with a focused message.

If blocked:

- Leave checkbox unchecked.
- Add a blocker note directly under the item using:
  - `Blocker (YYYY-MM-DD): <reason>. Evidence: <file/command/test output>.`

## Coding Standards

- Preserve existing runtime behavior unless the item requires behavior changes.
- Prefer explicit, deterministic output structures.
- Keep CLI/help/config/documentation synchronized when adding flags.
- Add stable tests for new behavior (fixture + script regression).
- Avoid introducing non-deterministic output ordering.

## Agent Readability and Search Hygiene

- Prioritize copyable examples over tests: examples should model the most token-efficient idioms we want agents to imitate.
- Treat README Quick Start and Examples as the canonical user-facing examples.
- Treat `tests/fixtures/**` as regression contracts, not style guidance; do not shorten fixtures when explicit output improves contract clarity.
- Treat `tests/fixtures/test005/snapshots/**` as generated golden output. Do not copy its prose style into docs or examples.
- Exclude generated/bulk paths from the main sweep unless the task explicitly targets them; document the search exclusions you used.
- Use this default broad-sweep shape, then narrow as needed: `rg <pattern> README.md docs lib scout.kujo tests/scripts -g '!tests/tmp/**' -g '!results/**'`.
- There are no expected-fail or legacy examples in the current tree. If one is added, label it near the file or command that uses it and explain why it remains.

## Testing Standards

Use the aggregate command for broad validation:

```bash
# Full suite
 tests/scripts/run_all_scout_tests.sh

# Fast local loop (skips slow ARC-002 root-scan case)
SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh
```

When working on a focused item, run its targeted script first, then run the fast aggregate suite.

## Prerequisites and Environment Checks

Before starting a loop, verify required tooling:

```bash
# Kujo binary must support script execution
kujo run --help >/dev/null

# JSON parser used by regression scripts
jq --version

# Schema validator required by FEAT-003/005/006/007 checks
python3 -c "import jsonschema; print(jsonschema.__version__)"
```

If `jsonschema` is missing:

```bash
python3 -m pip install --user jsonschema
```

If multiple Kujo binaries exist on the machine, pin the runtime for test runs:

```bash
KUJO_BIN=/absolute/path/to/kujo tests/scripts/run_all_scout_tests.sh
```

CI uses a pinned Kujo runtime tag (`SCOUT_CI_KUJO_REF` in `.github/workflows/repo-checks.yml`) to prevent version/source drift.

## Checklist and Docs Updates

For every completed item:

- Update the item checkbox in docs/SCOUT_EVOLUTION_CHECKLIST.md.
- Append a work-log entry including:
  - Date
  - Summary
  - Files changed
  - Tests/validation
  - Docs updated
  - Notes

## Commit Standards

- One commit per completed checklist item.
- Use concise, action-oriented messages.
- Keep commit scope aligned to checklist item scope.

Preferred style examples:

- `feat: add optional SARIF and JSONL security exports`
- `test: add cross-language route matrix snapshots`
- `docs: expand README architecture and testing guidance`

## Suggested Workflow for Agents

- Start from a clean working tree.
- Avoid editing generated outputs under tests/tmp.
- Remove temporary outputs before commit.
- Re-run the relevant tests after any fix.
- Leave repository in a clean state (`git status --short` empty).
