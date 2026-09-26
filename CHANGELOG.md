# Changelog

All notable changes to Scout are documented in this file.

This project follows a lightweight variation of Keep a Changelog and semantic versioning.

## [Unreleased]

### Added
- Add opt-in strict partial-scan exits, literal Fastify object-route discovery,
  bounded source reads, and deterministic large-scan benchmark coverage.
- Add versioned performance regression ceilings, labeled route/security
  precision-recall targets, and checked-in verification receipts.
- Add configurable aggregate ceilings for traversal, selected files, analyzed
  bytes, analysis results, and ignore rules.

### Fixed
- Root and bound target-relative baseline and ignore-file reads, reject paths
  outside the target, and fail closed on oversized metadata.
- Neutralize repository-controlled Markdown structure and keep raw route/path
  data out of generated `AGENTS.md`.
- Hash-lock the Linux CI schema-validation dependency graph on a pinned runner ABI.
- Confine bounded source reads to a rooted handle under the target even when
  symlinks are swapped during discovery or analysis; tolerate disappearing
  paths in reports and preserve in-root alias handling.
- Enforce exact canonical path boundaries, retain whitespace in source paths, skip special files, and diagnose unavailable entries without dropping siblings.
- Redact sensitive lines consistently across security rules and suppress unsafe source prefixes in exports and fingerprints.
- Use structured JSON dependency results exclusively when parsing succeeds.
- Reject file targets and malformed numeric limits; report output creation errors explicitly.
- Repair CI's unavailable runtime ref with the immutable Kujo v1.3.1 release commit.

- Fixed compact `package.json` and `composer.json` dependency extraction.
- Fixed normalization of comma-separated Python imports, PHP `use` statements, Go import blocks, and JVM static imports.
- Fixed root-route discovery for Next.js Pages Router and App Router APIs.
- Fixed middle-position wildcard matching in include/exclude globs.
- Fixed numeric line ordering for security findings.

### Changed
- Publish reports via staging and unique run directories; atomically replace
  accepted baselines after a complete report, and require a Kujo runtime with
  the rooted prefix-read API (minimum release 1.5.0).
- Install the official checksum-pinned Kujo 1.5.0 Linux and Windows binaries in
  CI, verify a native Windows Scout artifact workflow, and document the
  published runtime installation path instead of requiring a source build.
- Update the immutable checkout action pin to its Node.js 24 release.
- Scan useful hidden project directories and document production-readiness limits.
- Sort entries deterministically and use stable merge sorting with precomputed dependency and route keys.
- Avoid generating full-only documents in minimal mode or retaining all finding records when baseline writing is disabled.
- Add hardening regression checks to the aggregate suite and document partial-scan diagnostics.

## [1.0.0] - 2026-08-08

### Added
- Added launch-readiness Spec, Eval suite, examples surface, and Kujo/Kennel manifests for prelaunch review gates.
- Added redacted security finding output so credential, token, and private-key values are not serialized into reports, machine exports, or baseline fingerprints.
- Added dependency manifest extraction for Dart `pubspec.yaml`/`pubspec.yml`, SwiftPM `Package.swift`, and Elixir `mix.exs`.
- Added regression coverage for secret redaction and expanded dependency manifests.

### Changed
- Security keyword matching is now case-insensitive for common credential/token variants.
- Dangerous-call detection now avoids quoted-literal false positives across the dangerous execution rule family.
