# Scout Evolution Checklist

## Goal
Make Scout broadly useful, low-noise, and safe for adoption across different codebases while keeping it easy for agents and developers to extend.

## How Agents Must Work This Checklist
1. Read, in order: [README.md](../README.md), [scout.kujo](../scout.kujo), [config.json](../config.json), then this checklist.
2. Select the first unchecked actionable item in top-to-bottom order unless it is explicitly blocked.
3. Complete one item at a time (tests + implementation + docs for that item only).
4. Keep diffs scoped; do not batch unrelated work.
5. Mark completion by changing that item checkbox from `- [ ]` to `- [x]`.
6. Add a short completion note to Work Log after each completed item.
7. If blocked, keep the checkbox unchecked and add a dated blocker note directly under the item.

## Status Legend
- `- [ ]` not started
- `- [x]` completed
- Blocker note format:
  - `Blocker (YYYY-MM-DD): <reason>. Evidence: <file/command/test output>.`

## Current Findings Snapshot
- ARC-004 modularization is complete: `scout.kujo` is now a thin stable entrypoint and runtime/analyzer/report logic has been moved into focused modules under `lib/`.
  - Evidence: [scout.kujo](../scout.kujo), [lib/scout_runtime.kujo](../lib/scout_runtime.kujo), [lib/path_filters.kujo](../lib/path_filters.kujo), [lib/sorting.kujo](../lib/sorting.kujo), [lib/security_exports.kujo](../lib/security_exports.kujo), [lib/text_scan.kujo](../lib/text_scan.kujo)
- CI currently runs the fast path and skips the slow ARC-002 root-scan case, so full-suite confidence still depends on periodic full runs.
  - Evidence: [.github/workflows/repo-checks.yml](../.github/workflows/repo-checks.yml#L49), [tests/scripts/run_all_scout_tests.sh](../tests/scripts/run_all_scout_tests.sh#L34)
- Schema contract checks are wired via `jsonschema`; compatibility risk now centers on coverage breadth rather than validator absence.
  - Evidence: [tests/scripts/validate_json_schema.py](../tests/scripts/validate_json_schema.py), [tests/fixtures/schemas](../tests/fixtures/schemas), [.github/workflows/repo-checks.yml](../.github/workflows/repo-checks.yml#L35)
- Security findings now redact sensitive credential/token/private-key snippets before writing reports, exports, and baseline fingerprints.
  - Evidence: [lib/security_exports.kujo](../lib/security_exports.kujo), [tests/scripts/test_feat009_security_redaction.sh](../tests/scripts/test_feat009_security_redaction.sh)

## Tier 0: Correctness and Signal Quality (Do First)

### ARC-001 Fix language metrics population
- [x] Replace nested map writes with a safe local-map update pattern so language counts persist correctly.
- Implementation expectations:
  - Avoid nested direct assignment patterns that can fail at runtime.
  - Keep output schema unchanged.
- Acceptance criteria:
  - `README.md` output language section is populated when files are present.
  - `intelligence.json.metrics.languages` contains expected language counts.
- Validation/testing expectations:
  - Add regression test fixture proving non-empty language map on a mixed-language sample.
- Dependencies/unknowns:
  - Confirm preferred idiom for nested map mutation in current Kujo runtime.

### SEC-001 Prevent self-matching security findings
- [x] Exclude scanner definition blocks and generated output files from security pattern matching to avoid self-reporting.
- Implementation expectations:
  - Self-scan should still detect real findings outside detector definitions.
- Acceptance criteria:
  - Running Scout on itself does not report pattern-table lines as vulnerabilities.
- Validation/testing expectations:
  - Add a targeted fixture containing pattern definitions and real vulnerable lines; only real vulnerable lines should be reported.
- Dependencies/unknowns:
  - Decide whether exclusion is path-based, region-based, or both.

### SEC-002 Reduce dangerous-function false positives
- [x] Separate shell/code execution sinks from regex/API method names (`.exec`, etc.) and tighten matching heuristics.
- Implementation expectations:
  - Keep high-signal detections for true sink patterns.
- Acceptance criteria:
  - Regex `.exec(` usage is not flagged as dangerous code execution.
- Validation/testing expectations:
  - Add positive and negative tests for sink patterns.
- Dependencies/unknowns:
  - Decide whether to use token-aware matching or stronger string heuristics.

### ARC-002 Sanitize project slug and output path behavior
- [x] Normalize target slug generation so `.` and path edge-cases produce clean, stable output directory names.
- Implementation expectations:
  - Slug should be filesystem-safe and deterministic.
- Acceptance criteria:
  - Self-scan output path does not start with `.-`.
- Validation/testing expectations:
  - Add unit tests for `.`/relative/absolute target inputs.
- Dependencies/unknowns:
  - Keep backward compatibility for existing output folder naming where practical.

### ARC-003 Wire runtime to config.json
- [x] Load defaults from [config.json](../config.json) and apply them at runtime, with CLI flags taking precedence.
- Implementation expectations:
  - Config parse errors should be explicit and actionable.
- Acceptance criteria:
  - Updating config defaults changes runtime behavior without code edits.
- Validation/testing expectations:
  - Add tests for precedence: CLI > config > hard defaults.
- Dependencies/unknowns:
  - Decide if config path should be customizable via CLI flag.

## Tier 1: Architecture and DRY Improvements

### ARC-004 Split monolithic runtime into modules
- [x] Refactor [scout.kujo](../scout.kujo) into focused modules (CLI parsing, walker, dependency analyzers, route analyzers, security analyzers, report writers).
- Implementation expectations:
  - Keep `kujo run scout.kujo ...` as stable entrypoint (thin wrapper).
- Acceptance criteria:
  - Functional parity for current outputs and flags.
- Validation/testing expectations:
  - Snapshot compare against baseline outputs for at least 3 fixture repos.
- Dependencies/unknowns:
  - Decide module naming and folder layout (`src/`, `lib/`, etc.).

### ARC-005 Introduce shared parsing helpers
- [x] Centralize repeated quote extraction and token scan logic into reusable helper functions.
- Implementation expectations:
  - Remove obvious copy/paste parsing blocks.
- Acceptance criteria:
  - Equivalent extraction behavior for existing supported languages.
- Validation/testing expectations:
  - Add helper-level unit tests for edge cases (single/double/backtick quotes, escaped values).
- Dependencies/unknowns:
  - Confirm helper API surface for analyzers.

### ARC-006 Replace bubble sort for largest files
- [x] Replace O(n^2) sort loop with a more efficient strategy while preserving top-10 largest file output.
- Implementation expectations:
  - Maintain exact data shape for `metrics.largest_files`.
- Acceptance criteria:
  - Runtime performance improves on large repositories.
- Validation/testing expectations:
  - Add performance smoke test on a synthetic large file list.
- Dependencies/unknowns:
  - Validate available sort primitives in current Kujo runtime.

### ARC-007 Deterministic output ordering
- [x] Ensure stable ordering for languages, dependencies, routes, and findings across runs.
- Implementation expectations:
  - Stable output should not depend on map key iteration order.
- Acceptance criteria:
  - Two runs on same repo produce deterministic ordering.
- Validation/testing expectations:
  - Add snapshot test to verify stable output ordering.
- Dependencies/unknowns:
  - Define canonical sort keys per output type.

## Tier 2: Feature Expansion for Broader Utility

### FEAT-001 Add include/exclude filtering controls
- [x] Add CLI/config support for include/exclude globs and optional ignore file (for example `.scoutignore`).
- Implementation expectations:
  - Current defaults remain unchanged when no filters are provided.
- Acceptance criteria:
  - Users can restrict scan scope without editing source.
- Validation/testing expectations:
  - Add fixtures validating include-only and exclude-only behavior.
- Dependencies/unknowns:
  - Decide glob grammar and precedence.

### FEAT-002 Add path presentation modes
- [x] Add output mode for relative paths (default) vs absolute paths (optional), to improve privacy and reproducibility.
- Implementation expectations:
  - Existing consumers should remain compatible.
- Acceptance criteria:
  - All generated artifacts respect selected path mode.
- Validation/testing expectations:
  - Add tests for both modes.
- Dependencies/unknowns:
  - Confirm default should be relative-path safe mode.

### FEAT-003 Add machine-friendly security export
- [x] Add optional security export formats (JSONL and/or SARIF) for CI/security tooling integration.
- Implementation expectations:
  - Keep current markdown output untouched unless new flag is used.
- Acceptance criteria:
  - Export validates in downstream tooling.
- Validation/testing expectations:
  - Add schema validation test for exported format.
- Dependencies/unknowns:
  - Pick format scope for first release (SARIF-only vs SARIF+JSONL).

### FEAT-004 Add suppression baseline support
- [x] Implement baseline suppression file workflow for known accepted findings (`scout-baseline.json`).
- Implementation expectations:
  - Findings should include stable fingerprints.
- Acceptance criteria:
  - Suppressed findings are hidden unless explicitly requested.
- Validation/testing expectations:
  - Add regression test for fingerprint stability.
- Dependencies/unknowns:
  - Decide fingerprint fields (rule, file, line, snippet hash, etc.).

## Tier 3: Kennel-Oriented Integration

### FEAT-005 Emit Kennel-compatible index payload (optional mode)
- [x] Add optional mode to emit package/index metadata compatible with Kennel Stage 2 contracts.
- Implementation expectations:
  - Keep default Scout behavior unchanged.
  - New mode should map to Kennel `index.json` contract fields when possible.
- Acceptance criteria:
  - Generated index payload validates against `kujo-kennel/docs/contracts/index.schema.json`.
- Validation/testing expectations:
  - Add contract validation fixture using `kujo-kennel/docs/contracts/index.schema.json`.
- Dependencies/unknowns:
  - Align field mapping with `kujo-kennel/docs/stage-2-index-format.md`.

### FEAT-006 Emit per-project metadata for registry workflows
- [x] Add optional metadata output that can feed Kennel package metadata flows (`packages/<name>.json`-style contract).
- Implementation expectations:
  - Include source, ref/version hints where available.
- Acceptance criteria:
  - Metadata payload structure is compatible with Kennel package metadata conventions.
- Validation/testing expectations:
  - Validate against Kennel package metadata schema fixture.
- Dependencies/unknowns:
  - Determine which Scout-derived fields are authoritative vs inferred.

### FEAT-007 Add scan manifest for downstream automation
- [x] Add a small `scan_manifest.json` with schema version, run metadata, and artifact pointers for easier orchestration.
- Implementation expectations:
  - Keep backward compatibility with existing output files.
- Acceptance criteria:
  - External tools can resolve artifact paths from manifest alone.
- Validation/testing expectations:
  - Add schema validation test for manifest.
- Dependencies/unknowns:
  - Define schema versioning strategy.

## Tier 4: Test Coverage and Regression Safety

### TEST-001 Build fixture-based analyzer test suite
- [x] Create `tests/fixtures/` with minimal repos that exercise each parser family.
- Implementation expectations:
  - Keep fixtures tiny and purpose-built.
- Acceptance criteria:
  - Each supported parser has at least one positive and one negative fixture.
- Validation/testing expectations:
  - Add one command to run all Scout tests in CI.
- Dependencies/unknowns:
  - Choose native Kujo test runner conventions for this repo.

### TEST-002 Add route discovery regression matrix
- [x] Add route fixtures across Python/JS/PHP/Rust/Go/JVM/Kujo with edge-case syntax variants.
- Implementation expectations:
  - Include dynamic route placeholders and framework-specific quirks.
- Acceptance criteria:
  - Known false positives are prevented; expected routes are preserved.
- Validation/testing expectations:
  - Snapshot route table outputs per fixture.
- Dependencies/unknowns:
  - Determine minimum supported framework syntax variants.

### TEST-003 Add security precision/recall matrix
- [x] Add a security test matrix to prevent low-signal pattern regressions.
- Implementation expectations:
  - Include both true-positive and false-positive samples.
- Acceptance criteria:
  - Precision improves without losing high-value detections.
- Validation/testing expectations:
  - CI gate on matrix pass.
- Dependencies/unknowns:
  - Define acceptable precision threshold for baseline.

### TEST-004 Add CLI and config precedence tests
- [x] Add tests for CLI parsing, bad flags, depth edge-cases, and config precedence.
- Implementation expectations:
  - Explicitly test `--skip-*`, `-d`, `-o`, and positional target behavior.
- Acceptance criteria:
  - Regression-safe behavior for all public flags.
- Validation/testing expectations:
  - Add command-level tests and fixture assertions.
- Dependencies/unknowns:
  - Decide on expected behavior for unknown flags and malformed values.

### TEST-005 Add output golden snapshots
- [x] Add golden snapshots for all generated artifact files.
- Implementation expectations:
  - Normalize volatile fields (timestamps/output dirs) before comparison.
- Acceptance criteria:
  - Snapshot tests catch unintended output diffs.
- Validation/testing expectations:
  - CI should fail on unapproved snapshot drift.
- Dependencies/unknowns:
  - Define snapshot update workflow.

## Tier 5: Docs, DX, and CI Hardening

### DOC-001 Update README to match real architecture and workflow
- [x] Expand [README.md](../README.md) with module layout, config semantics, testing commands, and extension points.
- Implementation expectations:
  - Keep quick start concise, move deep details to docs.
- Acceptance criteria:
  - New contributor can run, test, and extend Scout from docs alone.
- Validation/testing expectations:
  - Verify all documented commands against actual repo behavior.
- Dependencies/unknowns:
  - Sync with any ARC-004 module path changes.

### DOC-002 Add contributor and agent workflow guide
- [x] Add `docs/CONTRIBUTING_SCOUT.md` with coding, testing, checklist, and commit standards.
- Implementation expectations:
  - Include a short "one item per loop" protocol.
- Acceptance criteria:
  - Future agents can follow a deterministic process.
- Validation/testing expectations:
  - Spot-check instructions by running one checklist item end-to-end.
- Dependencies/unknowns:
  - Finalize commit format preference.

### OPS-001 Strengthen CI beyond repo shape checks
- [x] Extend [.github/workflows/repo-checks.yml](../.github/workflows/repo-checks.yml) to run Scout tests and at least one fixture smoke scan.
- Implementation expectations:
  - Keep CI runtime reasonable.
- Acceptance criteria:
  - CI detects parser and output regressions.
- Validation/testing expectations:
  - CI workflow includes test + fixture run + artifact validation.
- Dependencies/unknowns:
  - Choose fixture size that keeps CI fast.

### OPS-002 Add release/versioning discipline
- [x] Add a lightweight release process with version bump checks and changelog conventions.
- Implementation expectations:
  - Avoid manual drift between runtime version and docs/config metadata.
- Acceptance criteria:
  - Version updates are consistent across files.
- Validation/testing expectations:
  - Add CI check for version consistency.
- Dependencies/unknowns:
  - Choose changelog format.

## Tier 6: Enterprise Hardening and Ecosystem Breadth

### FEAT-008 Enforce symlink traversal boundaries
- [x] Prevent scans from following outside-root symlink targets into unrelated filesystem content.
- Implementation expectations:
  - Keep in-root files scannable.
  - Do not leak outside-root paths or findings into generated outputs.
- Acceptance criteria:
  - Symlinked outside-root files do not appear in file tree, metrics, security findings, SARIF, or JSONL exports.
- Validation/testing expectations:
  - Add a fixture with inside-root findings and an outside-root symlink containing secrets.
- Dependencies/unknowns:
  - Continue validating behavior against Kujo runtime path semantics.

### FEAT-009 Redact sensitive security finding snippets
- [x] Redact credential, token, and private-key values before findings are written to reports, machine exports, and baseline fingerprints.
- Implementation expectations:
  - Preserve useful labels, paths, line numbers, severities, and key names.
  - Avoid raw secret values in `README.md`, `intelligence.json`, `security.sarif`, `security.jsonl`, and generated baselines.
- Acceptance criteria:
  - Security exports remain useful without serializing discovered secret values.
- Validation/testing expectations:
  - Add regression coverage for uppercase credential spellings, redacted snippets, and quoted dangerous-call literals.
- Dependencies/unknowns:
  - Future secret detectors should add matching redaction behavior before shipping.

### FEAT-010 Expand dependency manifest coverage
- [x] Add lightweight dependency extraction for Dart `pubspec`, SwiftPM `Package.swift`, and Elixir `mix.exs`.
- Implementation expectations:
  - Keep parsing deterministic and shallow; do not resolve package graphs.
  - Preserve existing dependency output schema.
- Acceptance criteria:
  - Scout identifies dependencies from common Dart, Swift, and Elixir manifests.
- Validation/testing expectations:
  - Add purpose-built manifest fixtures and aggregate test coverage.
- Dependencies/unknowns:
  - Future ecosystems should follow the same fixture-first pattern.

## Item Completion Template
Use this exact block in Work Log for each completed item:

```markdown
### <ITEM_ID> - <short title>
Date: YYYY-MM-DD
Summary: <what changed>
Files changed:
- <path>
- <path>
Tests/validation:
- <command>: <result>
Docs updated:
- <path>
Notes:
- <follow-up or "none">
```

## Work Log
### ARC-001 - Fix language metrics population
Date: 2026-05-22
Summary: Reworked language counting to update a local map and write back once per file, preventing empty language metrics in generated output.
Files changed:
- scout.kujo
- tests/scripts/test_arc001_languages.sh
- tests/fixtures/arc001/src/sample.py
- tests/fixtures/arc001/src/sample.js
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_arc001_languages.sh: passed
Docs updated:
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- none

### SEC-001 - Prevent self-matching security findings
Date: 2026-05-22
Summary: Security scanning now skips SECURITY_PATTERNS definition blocks and Scout-generated artifact files to avoid self-reporting noise.
Files changed:
- scout.kujo
- tests/scripts/test_sec001_self_match.sh
- tests/fixtures/sec001/security_patterns.kujo
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_sec001_self_match.sh: passed
- self-scan smoke with security findings review: passed
Docs updated:
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- none

### SEC-002 - Reduce dangerous-function false positives
Date: 2026-05-22
Summary: Added targeted `exec(` sink detection so method-style usages like regex `.exec()` are excluded while direct dangerous calls are still flagged.
Files changed:
- scout.kujo
- tests/scripts/test_sec002_exec_precision.sh
- tests/fixtures/sec002/exec_samples.js
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_sec002_exec_precision.sh: passed
- self-scan smoke with security findings precision checks: passed
Docs updated:
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- none

### ARC-002 - Sanitize project slug and output path behavior
Date: 2026-05-22
Summary: Added path-basename derivation plus slug sanitization to avoid dot-prefixed/invalid output folder names for `.` and edge-case targets.
Files changed:
- scout.kujo
- tests/scripts/test_arc002_slug_sanitization.sh
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_arc002_slug_sanitization.sh: passed
- tests/scripts/test_arc001_languages.sh: passed
- self-scan smoke (`$KUJO_BIN run scout.kujo . -d 2`): passed
Docs updated:
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- none

### ARC-003 - Wire runtime to config.json
Date: 2026-05-22
Summary: Added config.json default loading for max depth, output dir, max file size, ignored dirs, and analysis toggles with CLI flags retaining highest precedence.
Files changed:
- scout.kujo
- tests/scripts/test_arc003_config_precedence.sh
- tests/fixtures/arc003/src/level1/sample.py
- tests/fixtures/arc003/src/level1/level2/sample.js
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_arc003_config_precedence.sh: passed
- tests/scripts/test_arc001_languages.sh: passed
- tests/scripts/test_arc002_slug_sanitization.sh: passed
- self-scan smoke (`$KUJO_BIN run scout.kujo . -d 2`): passed
Docs updated:
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- none

### ARC-005 - Introduce shared parsing helpers
Date: 2026-05-22
Summary: Added a shared `first_quoted_value()` helper and replaced repeated first-quoted-token parsing blocks across dependency and route discovery paths.
Files changed:
- scout.kujo
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_arc001_languages.sh: passed
- tests/scripts/test_arc002_slug_sanitization.sh: passed
- tests/scripts/test_arc003_config_precedence.sh: passed
- tests/scripts/test_sec001_self_match.sh: passed
- tests/scripts/test_sec002_exec_precision.sh: passed
- self-scan smoke (`$KUJO_BIN run scout.kujo . -d 2`): passed
Docs updated:
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- ARC-004 was logged as blocked with evidence before selecting ARC-005 in this loop.

### ARC-006 - Replace bubble sort for largest files
Date: 2026-05-22
Summary: Replaced full-list bubble sort with a fixed-size top-k insertion strategy to keep only the 10 largest files during a single pass.
Files changed:
- scout.kujo
- tests/scripts/test_arc006_largest_files_topk.sh
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_arc006_largest_files_topk.sh: passed
- tests/scripts/test_arc001_languages.sh: passed
- tests/scripts/test_arc002_slug_sanitization.sh: passed
- tests/scripts/test_arc003_config_precedence.sh: passed
- tests/scripts/test_sec001_self_match.sh: passed
- tests/scripts/test_sec002_exec_precision.sh: passed
- self-scan smoke (`$KUJO_BIN run scout.kujo . -d 2`): passed
Docs updated:
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- none

### ARC-007 - Deterministic output ordering
Date: 2026-05-22
Summary: Added deterministic sorting for languages, dependencies, routes, and security findings so generated reports remain stable across runs.
Files changed:
- scout.kujo
- tests/scripts/test_arc007_deterministic_order.sh
- tests/fixtures/arc007/app.py
- tests/fixtures/arc007/app.js
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_arc007_deterministic_order.sh: passed
- tests/scripts/test_arc006_largest_files_topk.sh: passed
- tests/scripts/test_arc001_languages.sh: passed
- tests/scripts/test_arc002_slug_sanitization.sh: passed
- tests/scripts/test_arc003_config_precedence.sh: passed
- tests/scripts/test_sec001_self_match.sh: passed
- tests/scripts/test_sec002_exec_precision.sh: passed
- self-scan smoke (`$KUJO_BIN run scout.kujo . -d 2`): passed
Docs updated:
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- none

### FEAT-001 - Add include/exclude filtering controls
Date: 2026-05-23
Summary: Added include/exclude/ignore-file filter support across CLI and config, and fixed a Kujo runtime hang by removing continue-based control flow from matched filter paths.
Files changed:
- scout.kujo
- tests/scripts/test_feat001_include_exclude.sh
- tests/fixtures/feat001/.scoutignore
- tests/fixtures/feat001/src/include_me.js
- tests/fixtures/feat001/src/skip_me.js
- tests/fixtures/feat001/src/nested/keep.py
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_feat001_include_exclude.sh: passed
- tests/scripts/test_arc001_languages.sh: passed
- tests/scripts/test_sec001_self_match.sh: passed
- tests/scripts/test_sec002_exec_precision.sh: passed
- tests/scripts/test_arc002_slug_sanitization.sh: passed
- tests/scripts/test_arc003_config_precedence.sh: passed
- tests/scripts/test_arc006_largest_files_topk.sh: passed
- tests/scripts/test_arc007_deterministic_order.sh: passed
- smoke (`$KUJO_BIN run scout.kujo tests/fixtures/feat001 -o tests/tmp/feat001-smoke -d 3`): passed
Docs updated:
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- none

### FEAT-002 - Add path presentation modes
Date: 2026-05-23
Summary: Added relative/absolute path presentation mode support via config and CLI, and applied path-mode formatting across generated intelligence, route/dependency/security sources, and largest-file paths.
Files changed:
- scout.kujo
- tests/scripts/test_feat002_path_modes.sh
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_feat002_path_modes.sh: passed
- tests/scripts/test_feat001_include_exclude.sh: passed
- tests/scripts/test_arc001_languages.sh: passed
- tests/scripts/test_sec001_self_match.sh: passed
- tests/scripts/test_sec002_exec_precision.sh: passed
- tests/scripts/test_arc002_slug_sanitization.sh: passed
- tests/scripts/test_arc003_config_precedence.sh: passed
- tests/scripts/test_arc006_largest_files_topk.sh: passed
- tests/scripts/test_arc007_deterministic_order.sh: passed
Docs updated:
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- none

### FEAT-003 - Add machine-friendly security export
Date: 2026-05-27
Summary: Added optional SARIF and JSONL security exports via CLI/config (`--security-export`, `output.security_exports`) with stable rule IDs and export metadata in intelligence flags.
Files changed:
- scout.kujo
- config.json
- README.md
- tests/scripts/test_feat003_security_exports.sh
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_feat003_security_exports.sh: passed
- tests/scripts/test_arc001_languages.sh: passed
- tests/scripts/test_arc003_config_precedence.sh: passed
- tests/scripts/test_sec001_self_match.sh: passed
- tests/scripts/test_sec002_exec_precision.sh: passed
- tests/scripts/test_feat001_include_exclude.sh: passed
- tests/scripts/test_feat002_path_modes.sh: passed
- tests/scripts/test_arc006_largest_files_topk.sh: passed
- tests/scripts/test_arc007_deterministic_order.sh: passed
Docs updated:
- README.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- ARC-002 regression now uses a synthetic dot-target fixture to keep runtime stable; full suite re-run includes ARC-002 by default.

### FEAT-004 - Add suppression baseline support
Date: 2026-05-27
Summary: Added baseline suppression support with stable finding fingerprints, optional baseline generation, and visibility controls for suppressed findings.
Files changed:
- scout.kujo
- config.json
- README.md
- tests/scripts/test_feat004_baseline_suppression.sh
- tests/fixtures/feat004/src/app.py
- tests/fixtures/feat004/scout-baseline.json
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_feat004_baseline_suppression.sh: passed
- tests/scripts/test_feat003_security_exports.sh: passed
- tests/scripts/test_arc003_config_precedence.sh: passed
- tests/scripts/test_sec001_self_match.sh: passed
- tests/scripts/test_sec002_exec_precision.sh: passed
- tests/scripts/test_feat001_include_exclude.sh: passed
- tests/scripts/test_feat002_path_modes.sh: passed
- tests/scripts/test_arc001_languages.sh: passed
- tests/scripts/test_arc006_largest_files_topk.sh: passed
- tests/scripts/test_arc007_deterministic_order.sh: passed
Docs updated:
- README.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- Baseline fingerprints currently include rule ID, output path, line, severity, and snippet text for deterministic suppression matching.

### FEAT-005 - Emit Kennel-compatible index payload (optional mode)
Date: 2026-05-27
Summary: Added optional `--kennel-index` mode (and config toggle) that emits a Stage 2 compatible `index.json` package summary payload.
Files changed:
- scout.kujo
- config.json
- README.md
- tests/scripts/test_feat005_kennel_index.sh
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_feat005_kennel_index.sh: passed
- tests/scripts/test_feat004_baseline_suppression.sh: passed
- tests/scripts/test_feat003_security_exports.sh: passed
- tests/scripts/test_arc003_config_precedence.sh: passed
- tests/scripts/test_sec001_self_match.sh: passed
- tests/scripts/test_sec002_exec_precision.sh: passed
- tests/scripts/test_feat001_include_exclude.sh: passed
- tests/scripts/test_feat002_path_modes.sh: passed
- tests/scripts/test_arc001_languages.sh: passed
- tests/scripts/test_arc006_largest_files_topk.sh: passed
- tests/scripts/test_arc007_deterministic_order.sh: passed
Docs updated:
- README.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- `index.json` includes one package summary per scan target with `schema_version`, `generated_at`, `metadata_path`, and version source/ref fields aligned to Stage 2 index contract requirements.

### FEAT-006 - Emit per-project metadata for registry workflows
Date: 2026-05-27
Summary: Added optional `--kennel-metadata` mode (and config toggle) to emit `packages/<name>.json` metadata compatible with Kennel package metadata conventions.
Files changed:
- scout.kujo
- config.json
- README.md
- tests/scripts/test_feat006_kennel_metadata.sh
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_feat006_kennel_metadata.sh: passed
- tests/scripts/test_feat005_kennel_index.sh: passed
- tests/scripts/test_feat004_baseline_suppression.sh: passed
- tests/scripts/test_feat003_security_exports.sh: passed
- tests/scripts/test_arc003_config_precedence.sh: passed
- tests/scripts/test_sec001_self_match.sh: passed
- tests/scripts/test_sec002_exec_precision.sh: passed
- tests/scripts/test_feat001_include_exclude.sh: passed
- tests/scripts/test_feat002_path_modes.sh: passed
- tests/scripts/test_arc001_languages.sh: passed
- tests/scripts/test_arc006_largest_files_topk.sh: passed
- tests/scripts/test_arc007_deterministic_order.sh: passed
Docs updated:
- README.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- Metadata output includes required Stage 2 fields (`name`, `latest`, `repository`, `versions`) plus generated `description` and `published_at` context.

### FEAT-007 - Add scan manifest for downstream automation
Date: 2026-05-27
Summary: Added `scan_manifest.json` generation with schema version, run metadata, and concrete artifact pointers for both standard and optional output files.
Files changed:
- scout.kujo
- config.json
- README.md
- tests/scripts/test_feat007_scan_manifest.sh
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_feat007_scan_manifest.sh: passed
- tests/scripts/test_feat006_kennel_metadata.sh: passed
- tests/scripts/test_feat005_kennel_index.sh: passed
- tests/scripts/test_feat004_baseline_suppression.sh: passed
- tests/scripts/test_feat003_security_exports.sh: passed
- tests/scripts/test_arc003_config_precedence.sh: passed
- tests/scripts/test_sec001_self_match.sh: passed
- tests/scripts/test_sec002_exec_precision.sh: passed
- tests/scripts/test_feat001_include_exclude.sh: passed
- tests/scripts/test_feat002_path_modes.sh: passed
- tests/scripts/test_arc001_languages.sh: passed
- tests/scripts/test_arc006_largest_files_topk.sh: passed
- tests/scripts/test_arc007_deterministic_order.sh: passed
Docs updated:
- README.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- Manifest artifact pointers are relative to the run output directory so downstream tools can resolve files from manifest data alone.

### TEST-001 - Build fixture-based analyzer test suite
Date: 2026-05-27
Summary: Added parser-family fixture matrix (dependencies/routes/security positive+negative) and a single-command regression runner script for CI usage.
Files changed:
- tests/fixtures/test001/dependencies_positive/package.json
- tests/fixtures/test001/dependencies_negative/app.py
- tests/fixtures/test001/routes_positive/app.py
- tests/fixtures/test001/routes_negative/app.py
- tests/fixtures/test001/security_positive/secrets.py
- tests/fixtures/test001/security_negative/safe.js
- tests/scripts/test_test001_fixture_suite.sh
- tests/scripts/run_all_scout_tests.sh
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_test001_fixture_suite.sh: passed
- SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh: passed
Docs updated:
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- `run_all_scout_tests.sh` supports `SCOUT_SKIP_SLOW=1` to skip the expensive ARC-002 root-scan test during faster CI/dev loops.

### TEST-002 - Add route discovery regression matrix
Date: 2026-05-27
Summary: Added cross-language route fixtures (Python/JS/PHP/Rust/Go/JVM/Kujo) with snapshot-validated expected method/path extraction.
Files changed:
- tests/fixtures/test002/routes_python/app.py
- tests/fixtures/test002/routes_js/app.js
- tests/fixtures/test002/routes_php/web.php
- tests/fixtures/test002/routes_rust/main.rs
- tests/fixtures/test002/routes_go/main.go
- tests/fixtures/test002/routes_jvm/App.java
- tests/fixtures/test002/routes_kujo/app.kujo
- tests/fixtures/test002/snapshots/python.txt
- tests/fixtures/test002/snapshots/js.txt
- tests/fixtures/test002/snapshots/php.txt
- tests/fixtures/test002/snapshots/rust.txt
- tests/fixtures/test002/snapshots/go.txt
- tests/fixtures/test002/snapshots/jvm.txt
- tests/fixtures/test002/snapshots/kujo.txt
- tests/scripts/test_test002_route_matrix.sh
- tests/scripts/run_all_scout_tests.sh
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_test002_route_matrix.sh: passed
- SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh: passed
Docs updated:
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- Each fixture currently asserts exactly one expected route snapshot to minimize false positives and keep parser regressions obvious.

### TEST-003 - Add security precision/recall matrix
Date: 2026-05-27
Summary: Added security matrix fixtures with true-positive and false-positive samples plus a dedicated regression script to guard precision.
Files changed:
- tests/fixtures/test003/security_true_positive_credential.py
- tests/fixtures/test003/security_true_positive_exec.js
- tests/fixtures/test003/security_false_positive_regex_exec.js
- tests/fixtures/test003/security_false_positive_literal_exec.js
- tests/scripts/test_test003_security_matrix.sh
- tests/scripts/run_all_scout_tests.sh
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_test003_security_matrix.sh: passed
- SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh: passed
Docs updated:
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- Matrix currently enforces a deterministic baseline of two findings (credential + dangerous exec) and zero findings from false-positive fixtures.

### TEST-004 - Add CLI and config precedence tests
Date: 2026-05-27
Summary: Hardened CLI validation (unknown options, missing values, invalid depth values) and added a command-level regression matrix for option parsing and positional target behavior.
Files changed:
- scout.kujo
- tests/scripts/test_test004_cli_matrix.sh
- tests/scripts/run_all_scout_tests.sh
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_test004_cli_matrix.sh: passed
- SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh: passed
Docs updated:
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- Kujo runtime currently returns exit code `0` for some script-level errors, so CLI regression assertions key off explicit error message content.

### TEST-005 - Add output golden snapshots
Date: 2026-05-27
Summary: Added golden snapshot fixtures and a dedicated regression script that compares generated artifact outputs after normalizing volatile run fields.
Files changed:
- tests/fixtures/test005/snapshots/FILE_TREE.md
- tests/fixtures/test005/snapshots/README.md
- tests/fixtures/test005/snapshots/llms.txt
- tests/fixtures/test005/snapshots/AGENTS.md
- tests/fixtures/test005/snapshots/CHECKLIST.md
- tests/fixtures/test005/snapshots/intelligence.json
- tests/fixtures/test005/snapshots/scan_manifest.json
- tests/scripts/test_test005_golden_snapshots.sh
- tests/scripts/run_all_scout_tests.sh
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_test005_golden_snapshots.sh: passed
- SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh: passed
Docs updated:
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- Snapshot normalization currently replaces volatile JSON fields (`output`, `output_root`, `run_timestamp`, `generated_at`) before diffing.

### DOC-001 - Update README to match real architecture and workflow
Date: 2026-05-27
Summary: Expanded README with architecture layout, config precedence semantics, validated testing commands, and practical extension points for new contributors.
Files changed:
- README.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh: passed
Docs updated:
- README.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- README now documents both full and fast test commands plus fixture/script conventions for extension work.

### DOC-002 - Add contributor and agent workflow guide
Date: 2026-05-27
Summary: Added CONTRIBUTING guide with one-item-per-loop protocol, coding/testing standards, checklist update rules, and commit conventions.
Files changed:
- docs/CONTRIBUTING_SCOUT.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh: passed
Docs updated:
- docs/CONTRIBUTING_SCOUT.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- Guide includes the blocker-note format and clean-tree expectations for deterministic agent loops.

### OPS-001 - Strengthen CI beyond repo shape checks
Date: 2026-05-27
Summary: Extended GitHub workflow to install Kujo runtime (fallback build), run fast regression suite, and execute a fixture smoke scan with artifact assertions.
Files changed:
- .github/workflows/repo-checks.yml
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh: passed
- fixture smoke scan command with artifact assertions (`intelligence.json`, `scan_manifest.json`, `index.json`, `packages/arc001.json`): passed
Docs updated:
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- CI fast-path uses `SCOUT_SKIP_SLOW=1` to avoid ARC-002 runtime cost while still running the full regression matrix otherwise.

### OPS-002 - Add release/versioning discipline
Date: 2026-05-27
Summary: Added lightweight release workflow documentation, introduced changelog conventions, and added an automated version consistency check enforced in CI.
Files changed:
- .github/workflows/repo-checks.yml
- CHANGELOG.md
- docs/RELEASE_PROCESS.md
- tests/scripts/check_version_consistency.sh
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/check_version_consistency.sh: passed
- SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh: passed
Docs updated:
- CHANGELOG.md
- docs/RELEASE_PROCESS.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- Version consistency gate validates `scout.kujo` `VERSION` matches `config.json` `tool.version` and requires an `[Unreleased]` changelog section.

### TEST-006 - Expand security rule coverage matrix
Date: 2026-05-27
Summary: Added a full-rule security fixture matrix and regression script that asserts every built-in security label is exercised at least once.
Files changed:
- tests/fixtures/test006/hardcoded_credential.py
- tests/fixtures/test006/hardcoded_token.py
- tests/fixtures/test006/embedded_private_key.py
- tests/fixtures/test006/dangerous_exec.js
- tests/fixtures/test006/xss_sink.js
- tests/fixtures/test006/insecure_deserialization.py
- tests/fixtures/test006/weak_hash.py
- tests/fixtures/test006/benign.py
- tests/scripts/test_test006_security_rule_coverage.sh
- tests/scripts/run_all_scout_tests.sh
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_test006_security_rule_coverage.sh: passed
- SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh: passed
Docs updated:
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- Matrix now verifies label coverage for credential/token/private-key/exec/XSS/deserialization/weak-hash rule families to guard parser and pattern regressions.

### DOC-003 - Clarify local prerequisites and tooling checks
Date: 2026-05-27
Summary: Documented explicit local prerequisite checks for Kujo compatibility, jq availability, and Python jsonschema setup in README and contributor workflow docs.
Files changed:
- README.md
- docs/CONTRIBUTING_SCOUT.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh: passed
Docs updated:
- README.md
- docs/CONTRIBUTING_SCOUT.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- Documentation now includes runtime pinning guidance (`KUJO_BIN=/absolute/path/to/kujo ...`) for machines with multiple Kujo binaries.

### OPS-003 - Pin Kujo compatibility strategy in CI
Date: 2026-05-28
Summary: Reworked CI runtime installation to always build Kujo from pinned tag `v0.14.0`, export deterministic `KUJO_BIN`, and validate `run` subcommand support before test execution.
Files changed:
- .github/workflows/repo-checks.yml
- README.md
- docs/CONTRIBUTING_SCOUT.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh: passed
Docs updated:
- README.md
- docs/CONTRIBUTING_SCOUT.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- CI no longer depends on any preinstalled `kujo` binary on the runner, reducing ambiguity from host image changes.

### ARC-004 (Phase 1) - Extract path/filter utility module
Date: 2026-05-28
Summary: Started staged ARC-004 modularization by extracting slug/path/filter helpers into `lib/path_filters.kujo` and switching `scout.kujo` to import that module while preserving the CLI entrypoint.
Files changed:
- lib/path_filters.kujo
- scout.kujo
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_arc002_slug_sanitization.sh: passed
- tests/scripts/test_feat001_include_exclude.sh: passed
- tests/scripts/test_feat002_path_modes.sh: passed
- SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh: passed
Docs updated:
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- ARC-004 remains open; this loop establishes module layout and import/export pattern for the next staged splits.

### ARC-004 (Phase 2) - Extract sorting utility module
Date: 2026-05-28
Summary: Continued staged ARC-004 modularization by extracting deterministic sorting helpers into `lib/sorting.kujo` and switching `scout.kujo` to import the shared sort functions.
Files changed:
- lib/sorting.kujo
- scout.kujo
- README.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_arc007_deterministic_order.sh: passed
- tests/scripts/test_test005_golden_snapshots.sh: passed
- tests/scripts/test_feat004_baseline_suppression.sh: passed
- SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh: passed
Docs updated:
- README.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- ARC-004 remains open; this loop reduces monolith risk surface while preserving output parity contracts.

### ARC-004 (Phase 3) - Extract security export helpers
Date: 2026-05-28
Summary: Continued staged ARC-004 modularization by extracting security export and fingerprint helpers into `lib/security_exports.kujo` and switching `scout.kujo` to import those functions.
Files changed:
- lib/security_exports.kujo
- scout.kujo
- README.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_feat003_security_exports.sh: passed
- tests/scripts/test_feat004_baseline_suppression.sh: passed
- tests/scripts/test_test003_security_matrix.sh: passed
- SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh: passed
Docs updated:
- README.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- ARC-004 remains open; this loop extracts security export primitives while preserving SARIF/JSONL and baseline fingerprint parity.

### ARC-004 (Phase 4) - Extract text scanning helpers
Date: 2026-05-28
Summary: Continued staged ARC-004 modularization by extracting quote/scanning helpers into `lib/text_scan.kujo` and switching `scout.kujo` to import those shared parser/security primitives.
Files changed:
- lib/text_scan.kujo
- scout.kujo
- README.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_sec002_exec_precision.sh: passed
- tests/scripts/test_test001_fixture_suite.sh: passed
- tests/scripts/test_test002_route_matrix.sh: passed
- SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh: passed
Docs updated:
- README.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- ARC-004 remains open; this loop extracts shared parser/security scanning primitives while preserving route and security precision parity.

### ARC-004 (Closure) - Finalize thin entrypoint + runtime core split
Date: 2026-05-28
Summary: Completed ARC-004 by moving the active runtime/orchestration into `lib/scout_runtime.kujo` and converting `scout.kujo` into a thin stable entrypoint that preserves `kujo run scout.kujo ...` behavior.
Files changed:
- scout.kujo
- lib/scout_runtime.kujo
- README.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_test004_cli_matrix.sh: passed
- tests/scripts/test_test002_route_matrix.sh: passed
- tests/scripts/test_test005_golden_snapshots.sh: passed
- SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh: passed
- tests/scripts/run_all_scout_tests.sh: passed
- real-world scan proof (`../kujo-ai-chat` with SARIF/JSONL/Kennel artifacts): passed
Docs updated:
- README.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- Snapshot parity evidence includes fixture route matrix and golden snapshots; runtime architecture now uses focused modules with thin entrypoint compatibility preserved.

### FEAT-008 - Enforce symlink traversal boundaries
Date: 2026-06-19
Summary: Added aggregate regression coverage that verifies outside-root symlink targets are excluded from file tree, metrics, security findings, SARIF, and JSONL outputs.
Files changed:
- tests/scripts/test_feat008_symlink_boundary.sh
- tests/scripts/run_all_scout_tests.sh
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_feat008_symlink_boundary.sh: passed
- SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh: passed
Docs updated:
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- Existing symlink boundary coverage was aligned with the new security redaction contract so inside-root findings remain labeled without leaking raw values.

### FEAT-009 - Redact sensitive security finding snippets
Date: 2026-06-19
Summary: Redacted credential/token/private-key snippets before report/export/baseline output, made security keyword matching case-insensitive, and generalized dangerous-call matching to avoid quoted-literal false positives.
Files changed:
- lib/scout_runtime.kujo
- lib/security_exports.kujo
- lib/text_scan.kujo
- tests/fixtures/feat004/scout-baseline.json
- tests/fixtures/feat009_security_redaction/app.py
- tests/fixtures/feat009_security_redaction/danger.js
- tests/scripts/test_feat009_security_redaction.sh
- tests/scripts/test_sec001_self_match.sh
- tests/scripts/test_feat008_symlink_boundary.sh
- tests/scripts/run_all_scout_tests.sh
- README.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_feat009_security_redaction.sh: passed
- tests/scripts/test_feat008_symlink_boundary.sh: passed
- SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh: passed
Docs updated:
- README.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- Baseline fingerprints now use redacted snippets, preventing baselines from becoming long-lived secret stores.

### FEAT-010 - Expand dependency manifest coverage
Date: 2026-06-19
Summary: Added deterministic manifest dependency extraction for Dart `pubspec.yaml`/`pubspec.yml`, SwiftPM `Package.swift`, and Elixir `mix.exs`.
Files changed:
- lib/scout_runtime.kujo
- tests/fixtures/feat010_dependency_manifests/pubspec.yaml
- tests/fixtures/feat010_dependency_manifests/Package.swift
- tests/fixtures/feat010_dependency_manifests/mix.exs
- tests/scripts/test_feat010_dependency_manifests.sh
- tests/scripts/run_all_scout_tests.sh
- README.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Tests/validation:
- tests/scripts/test_feat010_dependency_manifests.sh: passed
- SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh: passed
Docs updated:
- README.md
- docs/SCOUT_EVOLUTION_CHECKLIST.md
Notes:
- Manifest parsing remains shallow by design; Scout reports direct declarations without resolving transitive package graphs.
