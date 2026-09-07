# Scout repository hardening audit — 2026-09-07

## Repository and evidence boundary

- Repository: `kujolang/scout`; branch: `main`.
- Starting SHA: `682490313f0e1424d731eaf7892455569e171cee` (clean checkout).
- Ending implementation/CI SHA: `902cb2c2691684d5365d0cea3ac6965816760f3e`. The subsequent evidence commit records the audit, benchmark provenance, and receipts; use `git log -1 --format=%H -- docs/audits/repository-hardening.md` for its SHA.
- Purpose: a local, single-process Kujo CLI that traverses a repository and generates dependency, route, security-smell, metric, and agent-context artifacts. It does not execute scanned code, make model calls, or offer a hosted API.
- Implementation reviewed: `scout.kujo`, all five `lib/*.kujo` modules, configuration and package manifests, both CI workflows and their guard, test runners, schema validator, fixtures/snapshots, examples, release/contributor documentation, and readiness Spec/Eval declarations. Initial inventory: 121 tracked files; 3,460 lines across the five runtime modules.
- Production dependency: Kujo runtime/native filesystem, string, JSON, date, and collection builtins. No npm/Python runtime package tree, network client, persistent cache, worker pool, database, or model/provider integration exists in Scout itself. Bash, jq, and Python/jsonschema are verification dependencies.
- Integrations: Kennel index/metadata schema contracts, SARIF/JSONL consumers, generated context consumers, and Leash's documented Scout integration. Read-only inspection of Kujo native filesystem implementations and Leash/Scent integration docs informed compatibility. No sibling repository was modified. This was not an exhaustive census of external consumers.
- Search exclusions: generated `tests/tmp`, `results`, `.cache`, and golden-output bodies were kept out of cleanup searches; fixtures and snapshots were reviewed as contracts, not code to simplify.

## Baseline

`tests/scripts/run_all_scout_tests.sh` passed all **24** existing scripts before implementation, including the slow root/slug check. There were no baseline test failures. Logs remain locally in `docs/audits/artifacts/baseline-tests.log`; a compact durable receipt is in `artifacts/verification.json`.

Baseline runtime: local debug Kujo 1.3.1, SHA-256 `fa2ab23f1bcb780bc1a801c27bf83c769a3f47fd79ea7f9078bd6886d4584ffb`, Darwin x86_64. Prerequisites: jq 1.7.1-apple, Python 3.10, jsonschema 4.26.0. The normal test resolver chose the sibling debug runtime because `kujo` was not on this shell's PATH.

New adversarial checks failed before their corresponding fixes:

- Whitespace-suffixed sibling symlink accepted as inside the target.
- Whitespace in legitimate source paths removed.
- A sensitive line exposed through another finding rule or a complex prefix.
- A regular-file target reported success despite no directory scan.
- Nested metadata in valid JSON invented a dependency through the line fallback.
- A directory symlink cycle reanalyzed the same file at each depth without a diagnostic.

The failure receipts are `artifacts/hardening-before.txt`, `manifest-before.txt`, and `cycle-before.txt`. The named-pipe hang risk and swallowed per-directory failure boundary were established from source; the fixed behavior is exercised with actual filesystem fixtures. No pre-fix FIFO read was deliberately allowed to hang.

Two pre-existing operational defects were distinguished from test failures: the referenced evolution checklist had been deleted, and CI fetched nonexistent tag `v0.14.0` (`git ls-remote --exit-code` returned 2). The public v1.3.1 tag resolves to `dc4803598d0421b31ecfd3f1027732589f1e8df1`.

## Findings

| ID | Priority | Area | Finding | Evidence | Action | Status |
|---|---|---|---|---|---|---|
| H01 | P0 | Filesystem boundary | Trimming canonical components equated `project` and `project `, allowing a sibling symlink escape | `path_components`; failing boundary fixture | Preserve component bytes and significant output/filter-path whitespace | Fixed |
| H02 | P0 | Sensitive exports | Redaction depended on the finding label; a second rule exposed the same secret line, and arbitrary assignment prefixes could contain literals | `redact_security_snippet`, security loop; six-finding regression fixture and whole-artifact/baseline search | Classify matches once, share safe snippets, retain only simple prefixes | Fixed |
| H03 | P1 | Failure semantics | Broken entries could terminate sibling processing silently; file targets appeared successful; special files could block a read | Directory-level catch, `read_file`, real broken-link/FIFO/file-target checks | Per-entry diagnostics, regular-file gate, directory requirement, diagnostic count receipt | Fixed |
| H04 | P1 | Resource/determinism | Directory cycles repeat analysis and can multiply traversal work | Depth-two self-link probe | Track canonical ancestors per branch and diagnose cycle descent; preserve non-cycle aliases | Fixed |
| H05 | P1 | Performance | Insertion sorts are quadratic and reconstruct dependency/route keys during comparisons | Sorting implementation; 512-record before/after benchmark | Stable merge sort with keys computed once; preserve numeric security ordering | Fixed |
| H06 | P1 | CI | Pinned runtime tag does not exist | Remote ref query; prior CI config | Pin verified v1.3.1 commit, verify checkout SHA, use `cargo --locked`; read-only workflow permissions | Fixed configuration; fresh build blocked locally |
| H07 | P2 | Parser correctness | Successful structured JSON still ran the recovery parser | Nested metadata fixture | Run legacy recovery only when structured parsing fails | Fixed |
| H08 | P2 | Resource/context efficiency | Minimal scans constructed unused full documents; every scan retained redundant all-finding records | Runtime writers and collections | Build agent/checklist text only for full profile; retain all findings only for baseline writing | Fixed |
| H09 | P2 | Validation/observability | Numeric config conversion accepted malformed limits; output directory creation errors were swallowed | Config/writer source and isolated failure tests | Reject invalid numeric limits and diagnose creation failures explicitly | Fixed |
| H10 | P2 | Agent workflow | Canonical contributor/checklist references pointed to a removed file | README/docs links and tracked inventory | Restore a concise active checklist and work log; document boundaries and benchmark command | Fixed |
| H11 | P1 conditional | Live untrusted filesystem | Canonical check and file open remain separate; analysis size limit is applied after a full read | `read_file(path)` followed by truncation; native `read_file_beneath` contract | Document stable-checkout requirement; preserve compatibility pending rooted prefix-read design | Open; see follow-up |
| H12 | P2 | Publication/state | Reports and baseline are not a filesystem transaction; timestamp directories are not exclusively allocated | Sequential `write_file` calls, `create_dir_all`, manifest written last | Preserve error propagation and manifest-last convention; document transaction limitation | Open; needs concurrency design |

## Changes implemented

### H01–H04: scan and redaction boundaries

`lib/path_filters.kujo` no longer trims canonical components or emitted relative paths. Pattern rules retain their existing trimming rules, while the candidate filename remains exact. Existing slash/component matching semantics are preserved.

`lib/scout_runtime.kujo` now validates a directory target, sorts directory entries, handles individual entry failures without dropping siblings, records directory failures, skips non-regular files, checks canonical containment again before each read, and stops canonical ancestor cycles. Non-cycle in-root symlinks retain their existing support. Depth limits remain in force. New diagnostics reuse the existing `{file,error}` array shape and add a CLI count only when needed. Partial-scan success remains intentional and documented.

Security matching collects matched rules once, selects a redacted line before constructing any finding, and uses that snippet for every matching rule. `lib/security_exports.kujo` only preserves simple assignment-name prefixes, never arbitrary quoted source. The adversarial fixture checks all generated artifacts, SARIF, JSONL, and written baseline while retaining all six expected findings. Existing simple-prefix snapshots still pass.

Tests: `tests/scripts/check_hardening.py`, `test_hardening.sh`, and existing FEAT-008/009, SEC, schema, baseline, and golden suites. Tests use temporary filesystem fixtures, including actual symlinks and a FIFO, without executing fixture source.

### H05/H08: efficiency without output reduction

`lib/sorting.kujo` shares one stable bottom-up merge implementation. Dependency/route composite keys remain byte-for-byte equivalent to the old key functions; security ordering remains severity, file, numeric line, label. Equal-key input order and input non-mutation are checked against Python's stable-sort oracle for empty, singleton, duplicate, Unicode, and multi-record cases.

The comparison algorithm changes from quadratic insertion sorting to O(n log n) merging. This is a comparison-count claim, not a claim that interpreter allocations are O(n log n): Kujo collection copy-on-write costs still apply. No persistent cache, invalidation mechanism, or new production dependency was added.

Minimal mode avoids building unused AGENTS/CHECKLIST strings and joining the full tree. It still collects tree lines and complete structured intelligence, so it is not a streaming or bounded-total-memory mode. The redundant all-finding collection is only populated for `--write-baseline`; counts and suppression outputs remain available in every mode. Memory savings are source-supported; peak RSS was not measured and no byte/percentage memory claim is made.

### H07/H09: parser and failure contracts

Valid `package.json` and `composer.json` use structured parsing exclusively. The prior recovery parser is retained for malformed manifests rather than replacing it with a new heuristic. Existing manifest matrix and compact-JSON regression tests remain green.

Negative/non-integer numeric configuration values now fail explicitly. Zero remains valid. Configuration precedence, flag names, defaults, and valid-value types are unchanged. Output creation failures now name the failing root/directory; existing files are not clobbered by a failed directory-creation attempt.

### H06/H10: verification and developer workflow

CI now fetches and verifies an immutable published runtime commit, builds with the runtime's Cargo lockfile, and explicitly requests read-only repository permissions. No new runtime dependency was added. Test-only jsonschema remains the established dependency; no advisory-database or complete transitive runtime vulnerability audit is claimed.

The hardening script is part of both fast and full aggregate suites. The restored checklist records current work without inventing deleted history. README documents partial scans, significant paths, redaction/fingerprint changes, special files, cycles, and remaining filesystem limits. Contributor instructions match the immutable CI pin.

## Performance and efficiency

Three-sample medians on the same available release Kujo 1.3.1 binary. CPU time is measured for the child process; wall time is sensitive to this busy host.

| Case | Before CPU (s) | After CPU (s) | Before wall (s) | After wall (s) |
|---|---:|---:|---:|---:|
| 512-record sorting driver | 4.694230 | 2.241449 | 7.043057 | 2.486452 |
| 64-import / 64-route full scan | 1.663123 | 1.541892 | 2.049101 | 1.798758 |
| 64-import / 64-route minimal scan | 1.608568 | 1.556973 | 1.920756 | 2.026296 |

The sorting driver measurements include process startup and input construction. Minimal-scan wall time increased slightly in this sample despite lower child CPU time; no universal latency improvement or statistical significance is claimed.

`llms.txt` stayed at **287 bytes**, normal CLI receipts stayed at **9 lines**, and all context documents matched exactly. Full artifact totals were 15,731 → 15,728 bytes and minimal totals 13,080 → 13,077 bytes; those three-byte differences come from dynamic before/after output-path lengths and are **not** output-efficiency savings.

Source-file hashes, individual samples, and runtime hash `74078102b8da4a994438b361f8fb024c68f78ab3818811d18f237949cc861859` are preserved in `artifacts/benchmark.json`. The earlier debug-runtime 512-record probe measured the sort call itself at 14,420 → 2,324 ms in one sample; `artifacts/initial-sort-probe.json` records equal output hashes. The repeated release measurements above are the primary evidence.

Reproduce against the immutable starting revision:

```bash
python3 tests/scripts/benchmark_hardening.py ../kujo/target/release/kujo 682490313f0e1424d731eaf7892455569e171cee docs/audits/artifacts/benchmark.json
```

The benchmark records three samples per case, runtime binary hash, wall/child CPU times, receipt size, and artifact/context bytes. The end-to-end fixture contains 64 unique imports and 64 routes in reverse order. It asserts exact sorted-record and context-document equality and normalized intelligence equality across old/new source and repeated scans. Dynamic output paths and timestamps are the only fields removed for that comparison. Timings are observational, not flaky CI thresholds.

Scout makes no model calls and exposes no MCP/tool schema or conversation replay. Token counts are therefore not measured. `llms.txt` byte size and golden snapshots are the applicable context controls; bytes are not presented as tokens. Default CLI output remains a small receipt, with detailed evidence in files. JSON schema/snapshot checks retain deterministic content contracts. No binary-size or Scout build-time improvement is claimed because Scout is interpreted and owns no compiled build artifact.

## Security and compatibility

Reviewed boundaries: CLI/config input, repository filenames and content, canonical containment, symlinks/special files/cycles, source-to-finding redaction, baseline suppression, output writes, generated agent context, local helper exports, and CI inputs. Scout does not spawn a shell or execute source content. Network/SSRF, credentials for providers, queues/locks, databases, and model dispatch do not exist in the Scout runtime.

- Public API/helper exports: no removals or signature changes.
- CLI: flags/defaults unchanged. File targets and invalid numeric limits now fail; partial scans add a diagnostic-count line. Directory/file ordering is now deterministic.
- JSON/file/schema versions: unchanged. Existing `parse_errors` carries additional error values. Artifact names and optional exports remain unchanged.
- Configuration/environment: no new keys or variables; numeric values validated. `KUJO_BIN` and `SCOUT_SKIP_SLOW` remain test controls. CI's runtime ref changes only build provenance.
- Baselines: old files remain readable. Fingerprints for newly redacted complex/multi-rule lines or corrected whitespace paths can differ; review and regenerate those entries. Unsafe old fingerprint text is never re-exported merely to retain suppression.
- External consumers: code consuming valid existing schemas and normal CLI success output retains its contract. Consumers assuming arbitrary directory order, malformed-input success, or no partial-scan diagnostics may observe intentional bug fixes.
- Outputs remain repository-derived untrusted data; a generated `AGENTS.md` is not authority to execute instructions embedded in paths/content.

## Cross-repository follow-ups and remaining work

**H11 — P1 when scanning concurrently attacker-modified trees.** A repeated canonical check reduces the exposure window but does not make read/open atomic or protect an attacker-replaced trusted root. The pinned Kujo v1.3.1 implementation provides `read_file_beneath`, which rejects symlink components and rejects files above the supplied bound. Scout's established behavior follows in-root aliases and analyzes a prefix of larger files. A bounded, rooted prefix-read design must preserve or explicitly migrate those behaviors before adoption. Affected contract: Kujo filesystem builtins and Scout's truncation/path behavior. Evidence: `lib/scout_runtime.kujo` read block and Kujo `src/interpreter/native_functions/filesystem.rs` at the pinned commit. Recommended follow-up: prototype rooted prefix reads, tests for concurrent replacement and FIFO swaps, and a runtime minimum-version decision. No sibling change is required for the fixes in this pass; an additional native prefix-read primitive may be useful after that design review.

**H12 — P2, Scout-local.** Baseline rewriting and run publication are not atomic as a group, and concurrent timestamp collisions are possible. Readers should treat a newly completed manifest as the receipt for a stable run, not a transaction guarantee. Design exclusive run allocation and atomic baseline replacement with symlink-safe temporary creation; test crash/concurrent writers. No transactional or adversarial-write safety claim is made here.

**Verification environment — blocker.** Fresh pinned-runtime compilation could not complete on this host: default, two-job, and serial attempts encountered `Resource temporarily unavailable (os error 35)` while starting compiler/linker processes. Attempts were stopped when necessary; no unrelated processes were terminated. Available Kujo 1.3.1 binaries were used for Scout checks. A failed concurrent benchmark attempt was discarded. One intermediate suite invocation was invalidated by editing its shell runner while Bash was reading it (unexpected EOF); syntax was checked and the complete suite was rerun successfully without editing active scripts. Hosted Linux CI was not executed locally; the immutable source ref was verified remotely. Logs remain in `artifacts/runtime-build*.log` and `benchmark.log`.

**Needs more evidence:** compatibility below the tested 1.3.1 runtimes, peak memory under very large repositories, and generalized parser precision beyond the existing fixture matrix. Minimum-version metadata was not raised speculatively. The large analyzer module and language-specific parsers were reviewed but not gratuitously rewritten: contract-preserving incremental extraction requires a separately scoped benefit and tests.

**Not worth changing:** purpose-built repetitive fixtures, stable exported helpers, established artifact schemas, and duplicate-looking language syntax branches with different semantics. No P3 cosmetic cleanup was pursued. No known P0 remains from the validated findings; this is not a claim of exhaustive vulnerability absence.

## Verification receipt

- `tests/scripts/run_all_scout_tests.sh`
  - Passed: 24 original scripts before changes; debug Kujo 1.3.1.

- `KUJO_BIN="$PWD/../kujo/target/release/kujo" tests/scripts/run_all_scout_tests.sh`
  - Passed: all 25 final scripts, including six-finding redaction, cycle, FIFO, malformed config, and failure tests.

- `tests/scripts/test_hardening.sh`
  - Passed after fixes; failure probes retained separately.

- `tests/scripts/test_feat009_security_redaction.sh`
  - Passed.

- `tests/scripts/test_test005_golden_snapshots.sh`
  - Passed; no golden changes.

- `tests/scripts/test_arc007_deterministic_order.sh`
  - Passed.

- `tests/scripts/check_version_consistency.sh`
  - Passed: 1.0.0.

- `python3 tests/scripts/benchmark_hardening.py ../kujo/target/release/kujo 682490313f0e1424d731eaf7892455569e171cee docs/audits/artifacts/benchmark.json`
  - Passed: three samples per case and old/new equivalence.

- `../kujo/target/release/kujo run scout.kujo -- tests/fixtures/arc001 -o tests/tmp/audit-smoke -d 2 --security-export sarif --security-export jsonl --kennel-index --kennel-metadata`
  - Passed: fixture smoke and optional outputs.

- `../kujo/target/release/kujo run scout.kujo -- . --quick -o tests/tmp/audit-self-scan`
  - Passed: repository self-scan.

- `bash .github/scripts/check-kujo-tool-artifacts.sh 682490313f0e1424d731eaf7892455569e171cee HEAD`
  - Passed: artifact/ignore guard.

- `git diff --check 682490313f0e1424d731eaf7892455569e171cee HEAD`
  - Passed.

- `python3 -m py_compile tests/scripts/check_hardening.py tests/scripts/benchmark_hardening.py tests/scripts/validate_json_schema.py`
  - Passed.

- `for script in tests/scripts/*.sh .github/scripts/*.sh; do bash -n "$script" || exit 1; done`
  - Passed.

- `git ls-remote --exit-code --tags https://github.com/kujolang/kujo.git refs/tags/v0.14.0`
  - Exit 2: confirmed pre-existing missing tag.

- `git ls-remote --tags https://github.com/kujolang/kujo.git 'refs/tags/v1.3.*'`
  - Passed: verified peeled v1.3.1 ref.

- `cargo build --release --locked --manifest-path .cache/audit-runtime/Cargo.toml`
  - Blocked: host process exhaustion; also retried with -j 2 and -j 1 without completing.

The aggregate suite includes JSON/schema validation, route/security/manifest matrices, suppression, Kennel contracts, CLI negative tests, include/exclude/path modes, top-k metrics, and golden outputs. No separate Scout compiler, formatter, type-check configuration, hosted E2E service, or dependency-audit command is defined. The runtime executes all active modules during the suite.

All commands run from the Scout root unless stated otherwise. Verbose logs are local ignored artifacts; committed JSON/text receipts preserve outcomes, failure probes, and measurements. No tests were disabled, assertions weakened, timing thresholds added, or snapshot baselines updated to conceal failures.

## Follow-up capture receipt

SignalBox deduplication found no existing records for H11/H12. The older ecosystem CI
capture `cap_32bf8938-dd47-4fa8-be4e-c9e6752a6f9f` was not duplicated; its Scout ref
issue is resolved in this pass, while its other repositories are outside scope.

- H11 capture: `cap_dfdc21ae-4042-40b0-ac86-8c8926a426da`.
- H11 review signal: `sig_a39339e5-8343-4937-bdd2-53fcca47c63e`.
- H12 capture: `cap_9e63836b-c206-492b-ae00-f63999a1c946`; no signal created.
- Captures cite the audited implementation at `f5c62e4`; the final redaction refinement does not change these remaining filesystem boundaries.
- All three IDs passed exact retrieval and concept search. Captures distinguish
  source-supported risks from reproduced exploits. Completed fixes, routine
  verification, and transient host-resource failures were rejected as capture topics.
