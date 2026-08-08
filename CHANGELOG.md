# Changelog

All notable changes to Scout are documented in this file.

This project follows a lightweight variation of Keep a Changelog and semantic versioning.

## [Unreleased]

## [1.0.0] - 2026-08-08

### Added
- Added launch-readiness Spec, Eval suite, examples surface, and Kujo/Kennel manifests for prelaunch review gates.
- Added redacted security finding output so credential, token, and private-key values are not serialized into reports, machine exports, or baseline fingerprints.
- Added dependency manifest extraction for Dart `pubspec.yaml`/`pubspec.yml`, SwiftPM `Package.swift`, and Elixir `mix.exs`.
- Added regression coverage for secret redaction and expanded dependency manifests.

### Changed
- Security keyword matching is now case-insensitive for common credential/token variants.
- Dangerous-call detection now avoids quoted-literal false positives across the dangerous execution rule family.
