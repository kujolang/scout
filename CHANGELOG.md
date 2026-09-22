# Changelog

All notable changes to Scout are documented in this file.

This project follows a lightweight variation of Keep a Changelog and semantic versioning.

## [Unreleased]

### Added
- Add opt-in strict partial-scan exits, literal Fastify object-route discovery,
  bounded source reads, and deterministic large-scan benchmark coverage.

### Fixed
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
  accepted baselines after a complete report, and declare Kujo 1.3.1 minimum.
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
