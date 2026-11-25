# Scout performance hardening, 2026-11-25

## Repository and scope

- Repository `kujolang/scout`, branch `main`. Clean starting revision `f3a874fa0e95e26c52ef9ec4d23b0f52d8372089`. Ending implementation revision `657209d0719d9f8839953a588f47fffdb85b683f`.
- Scout is a local Kujo CLI that discovers source files, analyzes dependencies, routes, and security smells, and publishes reports and context packs. Production uses Kujo 1.5.0 built-ins. Downstream consumers include agents, Kennel, and SARIF/JSONL readers. Bash, jq, and Python support verification.
- The pass focused on runtime performance and temporary collection costs. Package and runtime dependencies, CLI flags, configuration, environment variables, schemas, and supported artifact layouts are unchanged.

## Findings and changes

| ID | Priority | Finding | Evidence and action | Status |
|---|---|---|---|---|
| PERF-005A | P1 | Scout repeatedly copied growing dependency and route arrays while adding records. | Kujo 1.5.0 array `push` copies when the existing array is shared. `lib/scout_runtime.kujo` writes each accepted record to a dense numeric key and materializes each array once in discovery order. The existing deduplication and limit checks use the same membership and counts. | Fixed, high confidence |
| PERF-005B | P1 | Sorting rebuilt arrays on every interpreted merge step. | `lib/sorting.kujo` uses native string ordering for paths and composite-key groups. Each group preserves insertion order across equal composite keys. Security findings use two reusable merge buffers and retain their numeric line and label comparators. ARC-007 covers collisions, equal-key stability, input preservation, and numeric lines. | Fixed, high confidence |
| PERF-005C | P2 | Discovery compared each filename against both suffix tables and rendered file-tree rows even in minimal mode. | `lib/scout_runtime.kujo` extracts the final dotted suffix once and gates tree formatting by profile. ARC-001 covers dotfiles, compound and trailing dots, case, ignored extensions, and special manifests. The same files and diagnostics flow through both profiles. | Fixed, high confidence |

## Performance and output equivalence

Both revisions ran on the same shared Darwin x86-64 host with Kujo 1.5.0 (binary SHA-256 `3e1e475ea165c8b4a714495596fe8661ad970b27119ad44f1db4d9779f7f05d4`). The full benchmark ran one sample per revision with identical fixture hashes. Child CPU is the primary comparison because other host workloads varied during the runs. The pre-change elapsed ceilings failed for the many-file and route-heavy workloads. Every post-change elapsed, memory, and output-size ceiling passed.

| Full workload | Child CPU before → after | Wall time before → after | Peak RSS before → after | Report bytes both runs |
|---|---:|---:|---:|---:|
| 1,024 files, 1,024 routes | 18.549 → 6.332 s (66% less) | 85.585 → 30.994 s | 53.9 → 52.9 MiB | 186,434 |
| 32 files, 2,048 routes | 44.622 → 8.602 s (81% less) | 129.629 → 26.801 s | 65.6 → 72.0 MiB | 401,118 |
| Two 32 MiB source files | 0.202 → 0.220 s | 0.580 → 0.686 s | 41.1 → 41.2 MiB | 2,954 |

The route-heavy workload used about 10% more peak memory and stayed within the existing ceiling. The bounded large-source scan is a control with no material claim based on its single sample. Build size and token counts were outside the measured scope.

Three repeated comparison scans on a separate 64-route fixture produced exactly the same context documents and normalized intelligence on both revisions. The 512-record sort produced the same ordered records every time. Its median isolated sort time fell from 2,412 ms (1,991–3,080 ms) to 80 ms (41–154 ms). The aggregate suite independently checks golden documents, schemas, and analyzer behavior. The [measurement receipt](artifacts/performance-hardening-2026-11-25.json) preserves the individual results and fixture hashes.

## Checklist coverage and boundaries

| Phases | Scope and evidence |
|---|---|
| 0–1 | Read the entrypoint, scan modules, configuration, package manifests, regression drivers, performance budgets, and CI. Captured the starting SHA, aggregate baseline progress, and full pre-change performance receipt. |
| 2–4 | Traced repeated allocations in traversal, collection, and sorting. Retained the bounded rooted reader and all configured scan limits. No persistent cache or service resources are involved in these paths. |
| 5–6, 15 | Checked quick/full publication, short CLI receipts, `llms.txt`, and links to structured results. Minimal mode skips tree construction and publishes the same compact artifacts. The CLI has no model calls, tool-schema registration, agent replay, or retry loop to optimize. |
| 7–9 | Preserved discovery order, canonical path checks, rooted reads, strict and partial-scan diagnostics, staging, and baseline publication. Regression coverage exercises filesystem boundaries, redaction, and failure recovery. A general vulnerability assessment was outside the performance scope. |
| 10–11 | Checked flags, output profiles, manifests, runtime floor, and the CI pin. No dependency changes or public contract migrations were needed. No cross-repository changes are required. |
| 12–14 | Added behavior assertions to the existing regression scripts and kept the existing performance ceilings. Future intentional growth can update `tests/performance_targets.json` with reproducible evidence. Updated the performance and evolution documentation. |
| 16–18 | Removed the now-unused security sort-key formatter after checking its callers. Kept public helpers and compatibility behavior. Reran targeted and aggregate tests and the performance workloads. |

## Verification

- `KUJO_BIN="$(command -v kujo)" tests/scripts/run_all_scout_tests.sh` passed all 37 scripts on the candidate. The first baseline run hit a host disk-space error at script 28. Scripts 28–37 passed on the unmodified archive after free space recovered, completing baseline coverage.
- `python3 tests/scripts/benchmark_large_scans.py --kujo "$(command -v kujo)" --targets tests/performance_targets.json --output <receipt>` passed on the candidate in full and `--fast` modes. The baseline full run passed its output, memory, and count checks and exceeded the two elapsed ceilings listed above.
- `python3 tests/scripts/benchmark_hardening.py "$(command -v kujo)" f3a874fa0e95e26c52ef9ec4d23b0f52d8372089 <receipt>` passed exact sort and context document comparison, including normalized intelligence across versions.
- `python3 tests/scripts/profile_route_hotspot.py --kujo "$(command -v kujo)" --routes 512 --output <receipt>` passed three times on each revision, alternating baseline and candidate.
- `tests/scripts/check_version_consistency.sh`, `bash -n` over the shell scripts, `git diff --check`, and `bash .github/scripts/check-kujo-tool-artifacts.sh f3a874fa0e95e26c52ef9ec4d23b0f52d8372089 HEAD` passed locally.

## Remaining work

This performance pass closed PERF-005. The existing portability, parser coverage, release provenance, and diagnostics queue remains documented in the [Scout review backlog](../SCOUT_NEXT_REVIEW_2026-09-25_ROUND_2.md). Native Windows and Linux CI run through the existing hosted workflows.
