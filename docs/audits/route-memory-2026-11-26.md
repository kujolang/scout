# Scout route-heavy peak memory, 2026-11-26

## Scope and baseline

Scout is a local Kujo 1.5.0 repository scanner that publishes reports and structured context. This follow-up targets route-heavy scan memory and latency on `main`, from `6fe56d604661b2cf4dc1edcc018492020217f244` to implementation commit `c3ae5442a548187be3bd7571d637d9b549e33227`. The [previous performance audit](performance-hardening-2026-11-25.md) reported a route-heavy peak RSS increase from 65.6 to 72.0 MiB.

The baseline passed all 37 regression scripts and the full benchmark gate. The route-heavy workload uses 32 files, 2,048 routes, and 2,048 dependencies. It ran with the same Kujo 1.5.0 binary on Darwin x86-64 (SHA-256 `3e1e475ea165c8b4a714495596fe8661ad970b27119ad44f1db4d9779f7f05d4`).

## Findings and fixes

| Priority | Finding | Evidence and implementation | Status |
|---|---|---|---|
| P1 | Markdown rendering repeatedly pushed into a growing shared array. | Kujo 1.5 performs copy-on-write for shared arrays. The report-only experiment lowered peak RSS to 53.8–54.8 MiB, from 73.5–74.1 MiB in the paired controls. `lib/scout_runtime.kujo` now reserves all rows for each result section in one append and fills those slots by index. | Fixed |
| P2 | Sorting and publication overlapped with discovery buffers and per-key singleton arrays. | Discovery maps are released as soon as their contents have been materialized. `lib/sorting.kujo` stores the common unique record directly and creates an array only when a second record shares its composite key. Existing key ordering remains in Kujo's native dictionary traversal. ARC-007 now exercises three colliding routes to check that both creating a bucket and extending it preserve order. | Fixed |

The report-only prototype that relied on dictionary iteration failed exact Markdown comparison, so the final implementation uses array positions. Artifact paths, byte-level Markdown, routes, dependencies, diagnostics, ordering, CLI flags, config, and schemas match the established contracts. Runtime dependencies and the minimum Kujo version are unchanged.

## Performance and verification

Five interleaved runs per revision reused the existing full benchmark's `generate` and `run_case` with the same route-heavy fixture, input path, arguments, and runtime. Child CPU avoids conflating the scan's work with contention from other host processes.

| Route-heavy metric | Starting revision, median (range) | Candidate, median (range) |
|---|---:|---:|
| Peak RSS | 73.06 MiB (72.22–73.69) | 46.00 MiB (45.72–46.39) |
| Child CPU | 4.229 s (3.286–4.430) | 1.415 s (1.341–1.451) |
| Elapsed time | 4.348 s (3.569–4.622) | 1.521 s (1.428–1.545) |

Peak RSS fell 37% and child CPU fell 67% versus the starting revision. Candidate peak RSS also stayed below the historical pre-optimization 65.6 MiB value in every paired run. Two additional reruns of the historical revision `f3a874f` measured 62.66–73.63 MiB and 22.148–23.176 CPU seconds. These historical reruns serve as a speed and memory check, with the interleaved starting-revision comparison as the primary result.

The unchanged benchmark CLI also passed all three full-workload gates on both revisions and the candidate fast gate. These are the medians of three full runs per revision:

| Full workload | Peak RSS before → after | Child CPU before → after | Elapsed before → after |
|---|---:|---:|---:|
| Route-heavy | 72.43 → 46.09 MiB | 2.830 → 1.397 s | 2.922 → 1.484 s |
| 1,024 files | 50.48 → 36.24 MiB | 2.166 → 1.642 s | 2.273 → 1.740 s |
| Large-source control | 40.05 → 40.30 MiB | 0.096 → 0.091 s | 0.176 → 0.170 s |

Three 512-route profiles per revision kept quick and full scan outputs equivalent. Median quick scan time was 0.383 → 0.366 s, full scan time was 0.459 → 0.412 s, and isolated sorting was 7.743 → 6.729 ms.

The paired runs matched Markdown and text files byte for byte and matched the parsed intelligence and manifest after removing output-directory and timestamp fields. Fixture hashes, route and dependency counts, and diagnostic counts were identical. The [raw benchmark receipt](artifacts/route-memory-2026-11-26.json) preserves the results.

### Commands

All 37 regression scripts passed on both revisions. The full and fast gates, route profiles, cross-revision equivalence benchmark, and static and artifact checks passed.

- `KUJO_BIN="$(command -v kujo)" tests/scripts/run_all_scout_tests.sh` on baseline and candidate.
- `python3 tests/scripts/benchmark_large_scans.py --kujo "$(command -v kujo)" --targets tests/performance_targets.json --output <receipt>` on both revisions, plus `--fast` on the candidate.
- `python3 tests/scripts/profile_route_hotspot.py --kujo "$(command -v kujo)" --routes 512 --output <receipt>` on both revisions.
- `python3 tests/scripts/benchmark_hardening.py "$(command -v kujo)" 6fe56d604661b2cf4dc1edcc018492020217f244 <receipt>` for cross-revision equivalence.
- `tests/scripts/check_version_consistency.sh`, `bash -n tests/scripts/test_arc007_deterministic_order.sh`, `git diff --check`, and `bash .github/scripts/check-kujo-tool-artifacts.sh 6fe56d604661b2cf4dc1edcc018492020217f244 HEAD`.

## Checklist coverage and boundaries

Phases 0–4 covered the CLI entrypoint, route discovery, materialization, sorting, report rendering, and allocations. Phases 5–6 and 15 checked that the quick/full context packs, machine-readable report, and CLI output contracts were preserved. Scout has no model calls, replay, or tool-registration path. Phases 7–9 covered stable ordering, rooted reads, limits, redaction, and atomic publication through the existing regression suite. This performance pass did not assess vulnerabilities. Phases 10–14 covered package contracts, fixture snapshots, the existing benchmark ceilings, and focused tie coverage. Phases 16–18 removed temporary duplication, kept the supported output format, and repeated the same workloads and verification. There is no cross-repository dependency, remaining in-scope change, or new machine-specific threshold. Benchmark ceilings remain versioned in `tests/performance_targets.json`.
