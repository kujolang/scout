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
- [ ] REL-001: Make report and baseline publication recoverable. Reports are written
  individually and `--write-baseline` replaces its destination before the manifest
  completes (`lib/scout_runtime.kujo`, output section). Stage files and publish with
  atomic rename where the runtime supports it; test injected write failure and
  ensure old baselines survive unsuccessful scans.
- [ ] REL-002: Define explicit failure policy for partial scans. `parse_errors` can
  contain read failures or truncation while the process still exits successfully.
  Add an opt-in strict CI flag, document its exit status, and cover complete,
  truncated, and unreadable targets without changing the default behavior.
- [ ] FEAT-001: Expand discovery through opt-in language/plugin rules only after
  measurement. Route and dependency matching in `lib/scout_runtime.kujo` is
  framework-specific and largely line-based; collect representative user projects,
  report precision/recall, then prioritize missing frameworks. Avoid claiming
  comprehensive cross-language analysis.
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
