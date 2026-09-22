# Scout Release Process

This process is intentionally lightweight and designed for deterministic release hygiene.

## Version Sources of Truth

Scout version values must stay aligned across:

- scout.kujo (`VERSION := "x.y.z"`)
- config.json (`tool.version`)
- VERSION, kujo.toml, and kennel.toml (package `version`)

The minimum runtime version in both manifests is the first published release
with `read_binary_prefix_beneath` (1.5.0). CI installs the official Linux and
Windows x64 release archives and verifies the SHA-256 digests pinned in the
workflow. Update the CI version, archive digests, both minimum versions, and
runtime compatibility tests together when raising the supported runtime floor.

CI enforces this via `tests/scripts/check_version_consistency.sh`.

## Changelog Convention

Use `CHANGELOG.md` with these sections:

- `## [Unreleased]`
- `### Added`
- `### Changed`
- `### Fixed`

When preparing a release:

1. Move relevant entries from `[Unreleased]` into a new release heading:
   - `## [x.y.z] - YYYY-MM-DD`
2. Keep entries concise and user-impact focused.
3. Reset `[Unreleased]` sections back to placeholder `_None yet._` lines.

## Release Checklist

1. Ensure `main` is green.
2. Update version values in `scout.kujo`, `config.json`, `VERSION`,
   `kujo.toml`, and `kennel.toml`.
3. Update `CHANGELOG.md`:
   - Promote unreleased entries into a dated release section.
4. Run local validation:

```bash
SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh
tests/scripts/check_version_consistency.sh
```

5. Commit release prep changes.
6. Tag release:

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

## Hotfix Guidance

- Use patch version bumps (`x.y.Z+1`).
- Document only the hotfix delta in changelog.
- Re-run version consistency and fast test suite before tagging.
