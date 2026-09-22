# Scout follow-up review — 2026-09-22

Scout is a strong Kujo example and passes a broad local regression suite, but neither
universal usefulness nor enterprise-grade security can be established from that alone.
The items below are source-backed starting points for the next session, not claims of
exploitable vulnerabilities. Work top-to-bottom, one item per focused implementation
loop; include a fixture, focused regression, README update, and verification evidence.

## Completed in this review

- [x] REVIEW-001: Scan useful hidden directories, including `.github`, without
  dropping explicit ignored directories; exclude the generated output by its actual
  path rather than an unrelated same-named root directory. Regression:
  `tests/scripts/test_hidden_project_dirs.sh`.
- [x] REVIEW-002: Document the active root entrypoint, `lib/` layout, current
  limits, and readiness boundary in the README. There is no `src/` tree to consolidate.

## Next-session queue

- [x] PERF-001: Bound source reads before allocating the entire file. The runtime
  reads at most four bytes per configured character limit via `io_read_at`, then
  preserves Unicode character slicing and the `truncated_*` diagnostic. A 64 MiB
  fixture and multibyte/ordinary-file controls are in
  `tests/scripts/test_bounded_source_reads.sh`; see work log below.
- [ ] SEC-001: Harden the read boundary against concurrent symlink replacement.
  Canonical-path checks precede `read_file` but are not race-proof; the README
  currently requires a stable checkout. Explore file-descriptor-based or isolated
  runtime support before promising safe scanning of adversarial live trees. Add
  reproducible race tests and document the residual trust model.
  Blocker (2026-09-22): A compatible race-safe rooted prefix-read API is not
  available in the tested Kujo 1.3.1/1.4.0 runtimes. Existing rooted readers
  reject in-root aliases and files over 8 MiB; Scout's bounded `io_read_at`
  still follows pathnames and can reopen after UTF-8 boundary retries. Evidence:
  Kujo `src/interpreter/native_functions/{filesystem,io}.rs`, Scout
  `lib/scout_runtime.kujo`, `tests/scripts/test_bounded_source_reads.sh`.
  Changing the sibling Kujo runtime requires a separate scope decision.
- [x] REL-001: Make report and baseline publication recoverable. Write to a
  unique staging directory, publish the completed directory by rename, and
  atomically replace an accepted baseline only after the report is published.
  `tests/scripts/test_recoverable_publication.sh` injects report and baseline
  write failures and checks concurrent run isolation.
- [x] REL-002: Define explicit failure policy for partial scans. Opt-in
  `--strict` or `analysis.strict_scan` returns exit 2 on any diagnostic while
  publishing the report and retaining the prior baseline. Default behavior
  remains successful; `tests/scripts/test_strict_partial_scans.sh` covers
  complete, truncated, unavailable, and config cases.
- [x] FEAT-001: Measure route precision/recall for representative local
  projects, then add opt-in literal Fastify object-route discovery
  (`--rule fastify-object` / `analysis.optional_rules`). Positive/negative
  fixtures and the focused test confirm that default output is unchanged and
  dynamic paths, comments, unrelated receivers, and string examples are not
  reported as routes. No comprehensive cross-language claim is made.
- [ ] PERF-002: Benchmark very large repository scans and route/dependency-heavy
  inputs with stable fixture generation. Record wall time, peak memory, and report
  size; use measured hotspots to justify further modularization or indexing.
- [ ] DOC-001: Publish supported Kujo version range and reproducible installation
  instructions with CI parity. Keep `VERSION`, `config.json`, manifests, and release
  notes aligned; add tested macOS/Linux examples and state platform coverage honestly.

## Verification and scope

Repository review inspected the root entrypoint, all runtime helper modules, config,
package manifests, CI/test entrypoints, and README. Generated `results/` and
`tests/tmp/` were excluded from review; fixture snapshots are regression contracts.
Scout's own security findings are signals, not proof of safety. The optional Codex
Security workbench could not start in this environment because its Python runtime
lacked both `tomllib` and `tomli`; this is not a completed independent security audit.

## Work log

### 2026-09-22 — PERF-001

- Changed `lib/scout_runtime.kujo` to bound prefix reads instead of using the
  whole-file reader; the Unicode character limit, dependency parsing, and
  existing truncation diagnostics remain covered by the new focused test.
- Verified with 64 MiB, UTF-8 boundary, and ordinary input using local Kujo
  1.4.0 and 1.3.1. Peak resident size for the 64 MiB fixture scan on this macOS
  host was 23,236,608 bytes (`/usr/bin/time -l`); this is not a CI threshold.
- README now describes the read budget and the residual live-tree race.

### 2026-09-22 — REL-001

- Changed `lib/scout_runtime.kujo` output publication to a private staging
  directory, added a per-run random suffix, and made baseline replacement
  atomic after the complete report is published.
- Tested injected output write failure, denied baseline write with an existing
  file, normal replacement, and two concurrent report writers using local
  Kujo 1.4.0 and 1.3.1. The baseline and the directory are individually atomic,
  not one cross-file transaction; README states the residual limitation.

### 2026-09-22 — REL-002

- Added opt-in strict partial-scan failure (`--strict` / `analysis.strict_scan`)
  in `lib/scout_runtime.kujo`, with default outputs unchanged and no baseline
  replacement on strict failure. Updated `config.json` and README.
- Tested both local Kujo 1.4.0 and 1.3.1 with complete, truncated, unavailable,
  default-mode, and config-enabled scans; see the focused test script.

### 2026-09-22 — FEAT-001

- Before changing route rules, scanned three local project samples with their
  literal source declarations as the labeled reference set: `crud-api/src`
  (12/12), `cms/backend/routes` (136/136), and the RAG release-evaluation API
  example (2/2). For this 150-declaration sample, precision and recall were
  both 150/150. These counts cover only literal route calls, not runtime-resolved
  paths or all route forms in those projects.
- A purpose-built Fastify sample based on the official Fastify route contract
  had 1/4 literal routes discovered by default (25% recall, 100% precision
  against four labels). With `fastify-object`, the same sample has 4/4 recall
  and 4/4 precision. Negative cases exercise dynamic paths, unrelated receivers,
  comments, and strings. Fixture: `tests/fixtures/optional-rules/fastify/`;
  test: `tests/scripts/test_optional_fastify_rules.sh` on Kujo 1.3.1/1.4.0.
- Updated `lib/scout_runtime.kujo`, `config.json`, and README. The opt-in rule
  handles only single-line literal object calls and does not evaluate Fastify
  plugin prefix registration or dynamic paths.
