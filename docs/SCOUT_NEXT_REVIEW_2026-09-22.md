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
  reads at most four bytes per configured character limit (originally via
  `io_read_at`, now via `read_binary_prefix_beneath`), then
  preserves Unicode character slicing and the `truncated_*` diagnostic. A 64 MiB
  fixture and multibyte/ordinary-file controls are in
  `tests/scripts/test_bounded_source_reads.sh`; see work log below.
- [x] SEC-001: Root source-content reads in a trusted target directory handle.
  Kujo `599866bef0beb042c07751b77aa538db7f1a696c` adds
  `read_binary_prefix_beneath`, which reads a bounded regular-file prefix
  while confining relative symlinks to that opened root. Scout retains
  canonical in-root alias behavior and records disappearing paths as scan
  diagnostics. `tests/scripts/test_rooted_source_reads.sh` covers aliases,
  configured limits above 2 MiB, and repeated symlink swaps; Kujo's rooted
  filesystem and VM/interpreter tests cover FIFO, large files, capability
  gating, and alias swaps. The trusted root path itself must remain stable;
  filesystem metadata and opened file contents are not a snapshot.
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
- [x] PERF-002: Benchmark large repository scans and route/dependency-heavy
  inputs with deterministic fixture generation. Record wall time, child CPU,
  peak memory, report bytes, fixture digests, and verified route/dependency
  counts; use measured hotspots to prioritize future optimizations. The fast
  benchmark contract runs in the aggregate suite without timing thresholds.
- [x] DOC-001: Publish tested Kujo runtime points and reproducible installation
  instructions with CI parity. Align `VERSION`, `config.json`, project/package
  manifests, changelog, and release guidance; add a shared macOS/Linux
  quick-start smoke. Linux validation is through the pinned hosted CI job,
  not a claim of a local Linux execution.

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

### 2026-09-22 — PERF-002

- Added `tests/scripts/benchmark_large_scans.py` and a fast deterministic
  receipt check. Full benchmark on macOS / Kujo 1.4.0 (one run, observational):
  1,024 small source files / 1,024 routes+deps took 30.293s wall, 47,861,760
  bytes peak RSS, and 186,276 report bytes; 32 files / 2,048 routes+deps took
  50.067s wall, 76,525,568 bytes RSS, and 400,960 report bytes; two 32 MiB
  sources took 0.259s wall, 40,271,872 bytes RSS, and 2,796 report bytes.
  Exact fixture digests, CPU time, and artifact counts are preserved in
  `docs/audits/artifacts/large-scan-benchmark.json`.
- Route/dependency-heavy scans are the measured hotspot, not large content reads.
  Investigate per-record array construction and report assembly before indexing;
  any algorithm change needs profile-backed before/after measurements and output
  equivalence tests. No broad speedup claim is made from one host/run.

### 2026-09-22 — DOC-001

- Updated `kennel.toml` and `kujo.toml` minimum Kujo versions to 1.3.1, expanded
  `tests/scripts/check_version_consistency.sh` to compare all five active
  version sources, and recorded the current unreleased changes in CHANGELOG.
- Added README installation/support instructions and shared
  `tests/scripts/test_install_smoke.sh` on macOS and in Linux CI; updated
  `.github/workflows/repo-checks.yml` and `docs/RELEASE_PROCESS.md`.
- Local Kujo 1.3.1 and 1.4.0 smoke checks passed on macOS. Linux execution
  remains a hosted CI verification step and is not inferred from local results.

### 2026-09-22 — SEC-001

- Added `read_binary_prefix_beneath` in the sibling Kujo runtime, committed as
  `599866bef0beb042c07751b77aa538db7f1a696c`. Its capability-bound
  handle follows only symlinks confined to the trusted root, rejects special
  files without blocking, and reads a prefix even if the regular file is large.
  The same `filesystem-read` policy applies in VM and interpreter mode.
- Scout now captures the canonical in-root relative path and output label at
  discovery, then uses the rooted reader. This preserves alias handling and
  makes disappeared entries diagnostics instead of fatal report-format errors.
  Updated README, runtime minimum metadata, Linux CI pin, release guidance,
  and the focused alias/race/large-limit regression script.
- Verified the Kujo rooted unit tests, VM/interpreter capability parity,
  `cargo fmt --check`, `cargo check --locked`, and Scout's complete local test
  suite on the new source-built runtime. The new Linux CI pin requires its own
  hosted run; until Kujo publishes a compatible release, clone the pinned
  source commit as documented in README.
