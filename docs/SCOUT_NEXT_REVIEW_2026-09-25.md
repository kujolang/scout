# Scout enterprise review — 2026-09-25

Kujo 1.5.0 removed the runtime prerequisite that had blocked Scout's rooted-read
contract. This pass also completed the previously unavailable Codex Security workbench
scan, remediated its four validated findings, and converted performance and labeled
analysis quality from observations into release gates.

## Completed in this review

- [x] SEC-002: Root and bound default baseline and ignore-file reads; reject absolute,
  traversal, outside-root symlink, oversized, and excessive-rule inputs.
- [x] SEC-003: Remove raw repository routes and paths from `AGENTS.md`, encode
  repository-derived Markdown display values, and retain exact data in JSON.
- [x] SEC-004: Add aggregate entry, selected-file, analyzed-byte, result, and ignore-rule
  ceilings with fail-closed behavior and adversarial regressions.
- [x] SEC-005: Pin the Linux CI image/Python ABI and hash-lock the complete binary-only
  schema-validation dependency graph.
- [x] PERF-003: Define and enforce fast/full wall-time, peak-RSS, and report-size
  regression ceilings for deterministic many-file, route-heavy, and large-source cases.
- [x] QUAL-001: Define exact-match route/security precision and recall targets on a
  versioned labeled corpus and store a machine-readable receipt.
- [x] AUDIT-001: Complete a standard Codex Security scan of the immutable pre-fix
  revision; one high and three medium findings map to SEC-002 through SEC-005.

## Next-session queue

These are evidence and capability expansions, not known release blockers.

1. **QUAL-002 — Broaden labeled analysis coverage.** ✅ Add framework-specific positive
   and negative corpora for every documented route and manifest family, then publish
   per-family metrics instead of only aggregate exact-match scores.
2. **PERF-004 — Profile the route-heavy hotspot.** ✅ Use Kujo/runtime profiling to measure
   array rebuilding, sorting, and report assembly; accept optimizations only with output
   equivalence and improved full-benchmark receipts.
3. **PORT-001 — Expand native Windows coverage.** ✅ Move from the current artifact smoke
   to the portable non-Bash contract subset, or publish an equivalent PowerShell runner.
4. **REL-004 — Reproducible dependency-lock refresh.** ✅ Add a documented command that
   regenerates and verifies the CPython 3.12 Linux wheel hashes in a clean environment.
5. **UX-001 — Machine-readable limit diagnostics.** ✅ Preserve fail-closed resource
   ceilings while adding stable error identifiers for CI consumers.

## Acceptance evidence

- Complete local regression suite on official Kujo 1.5.0.
- Fast and full performance target receipts.
- Exact-match labeled analysis coverage receipt.
- Completed Codex Security report for revision
  `513b7406e04444b0f1b578288fd21f9f1c37023a`.
- Hosted Linux and Windows checks green after push.

Scout remains a heuristic local code-intelligence tool, not a universal static-analysis
oracle. Enterprise readiness here means explicit boundaries, deterministic failure,
reproducible release gates, and transparent corpus-scoped quality claims.

All five evidence/capability expansions were completed on 2026-09-25. The next
prioritized queue is in `SCOUT_NEXT_REVIEW_2026-09-25_ROUND_2.md`.
