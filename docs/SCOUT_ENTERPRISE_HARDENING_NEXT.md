# Scout Enterprise Hardening Review - 2026-06-19

## Current assessment

Scout is a strong Kujo-native showcase with a clean thin entrypoint, modular runtime helpers, deterministic outputs, fixture-backed regression tests, CI/version discipline, optional SARIF/JSONL/Kennel outputs, baseline suppression, and broad route/dependency/security coverage.

It is not yet something I would call universally enterprise-grade without qualification. It is production-leaning for local repository intelligence and agent context generation, but enterprise adoption still benefits from deeper profiling, more language/framework coverage, stronger output privacy controls, packaged distribution, and long-run compatibility testing.

## Completed in this review

- Redacted credential, token, and private-key snippets before writing findings to Markdown reports, `intelligence.json`, SARIF, JSONL, and baseline fingerprints.
- Made security keyword matching case-insensitive for common credential/token forms.
- Generalized dangerous-call matching so quoted literals such as `"eval("` and `"system("` are not flagged as executable sinks.
- Added dependency extraction for Dart `pubspec.yaml`/`pubspec.yml`, SwiftPM `Package.swift`, and Elixir `mix.exs`.
- Added regression scripts and fixtures for security redaction and new manifest parsers.
- Updated README, changelog, and the evolution checklist/work log.

## Root layout review

The current root files are still purposeful:

- `scout.kujo` remains the stable CLI entrypoint and should stay at repo root for `kujo run scout.kujo -- ...` compatibility.
- `config.json`, `README.md`, `CHANGELOG.md`, `LICENSE`, `.github/`, `docs/`, `lib/`, and `tests/` are active project files.
- `results/` is generated output and should not be treated as source. Consider removing tracked historical result artifacts if any are currently committed.
- There is no active `src/` folder in this repo; the runtime source is currently under `lib/`. If the project standard prefers `src/`, migrate in a dedicated compatibility-preserving change with import path tests.

## Next-session work items

1. Output privacy profiles
   - Add `--privacy-profile safe|full` or equivalent config.
   - Safe mode should redact snippets by default, avoid absolute paths unless requested, and include a concise explanation in generated reports.

2. Performance benchmark harness
   - Add a synthetic large-repo fixture or generated temp tree benchmark.
   - Track wall time, file count, byte count, max depth, and analyzer toggles.
   - Emit a lightweight benchmark report so performance changes are measurable.

3. Incremental scan cache design
   - Investigate file mtime/size/hash caching for repeated local scans.
   - Keep cache opt-in and safe to delete.
   - Document invalidation semantics before implementation.

4. Output schema hardening
   - Add JSON Schema coverage for `intelligence.json`.
   - Validate schema in CI alongside existing SARIF/JSONL/Kennel/manifest checks.

5. Additional ecosystem parsers
   - Add focused fixtures before code for Maven/Gradle, .NET `.csproj`, Terraform modules, Docker Compose, and GitHub Actions workflows.
   - Keep parsers shallow and deterministic.

6. Security rule metadata
   - Add rule IDs, descriptions, remediation hints, and precision notes directly to `SECURITY_PATTERNS`.
   - Ensure SARIF rules include remediation text without increasing false positives.

7. Secret redaction stress tests
   - Add fixtures for colon assignments, YAML values, JSON-like values, multiline private keys, and comments.
   - Confirm raw values never appear in any generated artifact.

8. Packaging and install story
   - Decide whether Scout should ship as a Kujo package, a pinned script bundle, or a Kennel-discoverable package.
   - Add installation instructions and smoke tests for the chosen path.

9. Results directory hygiene
   - Audit whether `results/` should be ignored, cleaned, or represented only by small fixture snapshots.
   - Remove stale generated artifacts from version control if they are not intentional examples.

10. Full-suite cadence
   - Keep CI fast, but document when maintainers should run the non-slow full suite.
   - Consider a scheduled full test workflow if runtime cost is acceptable.

## Suggested first action next time

Start with item 1, output privacy profiles. It builds directly on the redaction work from this session and gives enterprise users a clear default security posture.
