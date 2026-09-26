# Scout Evolution Checklist

This active checklist was restored during the 2026-09-07 hardening pass because
README and contributor instructions referenced a file removed by an earlier cleanup.
It records current work; it does not reconstruct historical checklist entries.
For the next prioritized implementation queue, see
[`SCOUT_NEXT_REVIEW_2026-09-25_ROUND_2.md`](SCOUT_NEXT_REVIEW_2026-09-25_ROUND_2.md).

- [x] HARD-001: Exact path boundaries, cross-rule redaction, scan diagnostics, numeric validation, and JSON fallback correctness; add behavioral regression coverage.
- [x] HARD-002: Stable merge sorting and removal of unnecessary report/finding retention; preserve output contracts and measure representative scans.
- [x] HARD-003: Repair the pinned CI reference and publish the audit with explicit verification limitations.
- [x] QUAL-002: Publish aggregate and per-family exact-match coverage for every documented route and manifest family.
- [x] PERF-004: Isolate array rebuilding, route sorting, and report-assembly profile evidence with output equivalence.
- [x] PORT-001: Run the portable route, security-export, and artifact contract subset natively on Windows.
- [x] REL-004: Deterministically regenerate and verify the Linux CPython 3.12 schema wheel hash lock.
- [x] UX-001: Emit stable identifiers for every fail-closed resource ceiling.

## Work Log

### 2026-09-07 — HARD-001

- Changed `lib/path_filters.kujo`, `lib/security_exports.kujo`, and the runtime scan,
  parser, diagnostic, and redaction paths.
- Added `tests/scripts/test_hardening.sh`, its Python assertions, and a sort-contract
  driver; the aggregate suite now includes these checks.
- Baseline: 24 existing scripts passed; four new boundary/redaction/failure assertions
  and a separate nested-JSON assertion reproduced defects before their fixes.
- Verification: focused hardening checks and the original golden/schema/parser suites;
  see the audit receipt for the final full-suite results.
- Docs: README boundary, diagnostic, and baseline compatibility notes; changelog.

### 2026-09-07 — HARD-002

- Replaced repeated insertion sorting/key calculation in `lib/sorting.kujo` with one
  stable merge implementation; preserved composite keys and numeric security line order.
- Minimal mode no longer constructs unused agent/checklist documents; scans without
  baseline writing no longer retain the redundant all-finding record collection.
- Added `tests/scripts/benchmark_hardening.py` and a 512-dependency sort fixture.
  Timings are recorded evidence, never machine-dependent CI thresholds.
- Validation: Python stable-sort oracle, non-mutation checks, existing snapshots,
  normalized before/after scan equality, and repeated benchmark samples (audit artifacts).

### 2026-09-07 — HARD-003

- Replaced nonexistent runtime tag `v0.14.0` with verified published release commit
  `dc4803598d0421b31ecfd3f1027732589f1e8df1`; CI verifies the fetched SHA and uses
  `cargo build --release --locked`, with read-only repository permissions.
- Fresh local runtime compilation remains blocked by host process exhaustion, including
  two-job and serial attempts. Available Kujo 1.3.1 binaries cover Scout verification;
  the audit distinguishes this blocker from passing local functional checks.
- Updated contributor guidance and the repository-local audit/measurement receipts.

### 2026-09-07 — final redaction review

- Restricted retained assignment prefixes to identifier/property characters after an
  optional recognized declaration; arbitrary unquoted multiword prefixes are redacted.
- Expanded the security fixture to six retained findings and reran all 25 scripts on
  the available release Kujo 1.3.1 binary. No golden snapshots changed.

### 2026-09-22 — repository follow-up review

- Preserved the published root entrypoint and active configuration/manifests;
  source modules remain in `lib/`, as there is no `src/` directory.
- Corrected hidden project directory discovery and exact output-root exclusion,
  with a focused regression script and fixture.
- Clarified readiness limits in the README and added the next-session queue in
  `docs/SCOUT_NEXT_REVIEW_2026-09-22.md`.

### 2026-09-25 — evidence and portability expansion

- Expanded labeled coverage to 18 route families and 10 dependency-manifest families,
  retaining the security corpus and publishing per-family scores.
- Added output-equivalent profiling for repeated array rebuilding, route sorting, and
  full-report assembly. No optimization was accepted without comparative evidence.
- Replaced the Windows artifact-only smoke with a native PowerShell contract subset.
- Added deterministic schema-lock regeneration/verification and offline tool coverage.
- Added stable `SCOUT-LIMIT-*` identifiers and behavioral checks for representative ceilings.
