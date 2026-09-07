# Scout Evolution Checklist

This active checklist was restored during the 2026-09-07 hardening pass because
README and contributor instructions referenced a file removed by an earlier cleanup.
It records current work; it does not reconstruct historical checklist entries.

- [x] HARD-001: Exact path boundaries, cross-rule redaction, scan diagnostics, numeric validation, and JSON fallback correctness; add behavioral regression coverage.
- [x] HARD-002: Stable merge sorting and removal of unnecessary report/finding retention; preserve output contracts and measure representative scans.
- [x] HARD-003: Repair the pinned CI reference and publish the audit with explicit verification limitations.

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
