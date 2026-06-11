# Scout Release Process

This process is intentionally lightweight and designed for deterministic release hygiene.

## Version Sources of Truth

Scout version values must stay aligned across:

- scout.kujo (`VERSION := "x.y.z"`)
- config.json (`tool.version`)

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
2. Update version values in:
   - scout.kujo
   - config.json
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
