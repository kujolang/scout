# Scout

[![Version](https://img.shields.io/badge/version-1.0.0-black)](https://github.com/kujolang/scout)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)
[![built with Kujo](https://img.shields.io/badge/built%20with-Kujo-white.svg)](https://github.com/kujolang/kujo)

Scout is a codebase intelligence tool built in [Kujo](https://github.com/kujolang/kujo) — it turns a local repository into an agent-readable context pack by mapping structure, dependencies, routes, and risk into structured outputs.

It helps agents and humans start from the same map of a codebase: file tree, language breakdown, dependency graph, route/API discovery, security smell detection, review checklist, and reviewable context files. Scout packages repository state; it does not replace human review or guarantee perfect understanding.

The examples in this README are the canonical copyable examples for Scout usage; tests and fixture snapshots are regression contracts, not style models.

## Quick Start

```bash
kujo run scout.kujo -- . --quick
```

Expected output shape:

```text
Scanning: .
Output: ./results/<project-name>-<timestamp>
Code files analyzed: <count>
Dependencies: <count>
Routes: <count>
Security findings: <count>
Output profile: minimal
Scan manifest: ./results/<project-name>-<timestamp>/scan_manifest.json
Done.
```

Common variants:

```bash
# Scan a specific project with full output artifacts
kujo run scout.kujo -- ../my-project

# Scan with custom output root and depth
kujo run scout.kujo -- ./src -o ./reports -d 3

# Security-focused scan
kujo run scout.kujo -- ./src --skip-deps --skip-routes -o ./security-audit
```

## Runtime

Scout runs natively on Kujo with a single entrypoint:

- **`scout.kujo`:** Primary CLI and active analyzer runtime.

Run with: `kujo run scout.kujo -- ...`

## What It Produces

| File | Description |
|------|-------------|
| `FILE_TREE.md` | Recursive directory tree showing files, sizes, and detected languages |
| `README.md` | Full report with metrics, routes, dependencies, and security findings |
| `llms.txt` | Compact project overview for context injection into downstream tools |
| `AGENTS.md` | Structured context for AI coding assistants |
| `CHECKLIST.md` | Code review checklist with security findings highlighted |
| `intelligence.json` | Full structured data dump for programmatic consumption |
| `scan_manifest.json` | Run manifest with schema version, metadata, and artifact pointers |
| `index.json` | Optional Kennel-compatible package index payload when `--kennel-index` is enabled |
| `packages/<name>.json` | Optional Kennel-compatible package metadata payload when `--kennel-metadata` is enabled |
| `security.sarif` | Optional SARIF v2.1.0 export when `--security-export sarif` is enabled |
| `security.jsonl` | Optional line-delimited security findings when `--security-export jsonl` is enabled |

## Capabilities

### File Tree Scanning
Recursively walks directories, skips VCS folders, `node_modules`, build artifacts, and binary/media files. Returns a structured tree with file sizes and language labels.

### Language Detection
Maps 50+ file extensions to language names — including Python, JavaScript/TypeScript, Rust, Go, PHP, Ruby, Java/Kotlin, and additional ecosystems such as Haskell, Zig, Swift, Dart, Elixir, Clojure, Scala, and more.

### Dependency Analysis
Parses dependency signals from both source code and ecosystem manifests:
- **Python**: `import X`, `from X import Y`, plus `pyproject.toml` (`[project].dependencies`, Poetry dependencies)
- **JS/TS**: `require()`, `import X from Y`, plus `package.json` (`dependencies`, `devDependencies`, `peerDependencies`, `optionalDependencies`)
- **PHP**: `use` statements, plus `composer.json` (`require`, `require-dev`)
- **Rust**: `use`, `extern crate`, plus `Cargo.toml` dependency sections
- **Go**: `import "package"`, plus `go.mod` `require` blocks
- **Ruby**: `require`, `require_relative`, `gem`, plus `Gemfile` `gem` entries
- **Java/Kotlin**: `import`, `package`
- **Haskell/Zig/Swift/Dart**: source import parsing
- **Dart**: `pubspec.yaml` / `pubspec.yml` dependencies and dev dependencies
- **Swift**: SwiftPM `.package(...)` entries in `Package.swift`
- **Elixir**: Mix dependency tuples in `mix.exs`
- **Python pip**: `requirements.txt` and `requirements-*.txt`
- **Kujo**: `import X`, `from X import Y`, quoted imports

### Route / API Discovery
Finds HTTP route definitions in popular frameworks:
- **Python**: Flask (`@app.route`), FastAPI (`@app.get`), Django (`path()`, `re_path()`)
- **JS/TS**: Express-style handlers (`app.get`, `router.post`) and Next.js file routes (`pages/api`, `app/api/.../route.ts`)
- **PHP**: Laravel (`Route::get`), Slim (`$app->get`), Symfony-style route annotations/attributes, and WordPress (`register_rest_route`, `wp_ajax_*`, `admin_post_*`)
- **Rust**: Actix/Axum (`.route("/path")`)
- **Go**: Gin (`router.GET`), `http.HandleFunc`
- **Java/Kotlin**: Spring (`@GetMapping`, `@PostMapping`, `@RequestMapping`)
- **Kujo**: `.route("GET", "/path", handler)`

### Security Smell Detection
Scans for a baseline set of security patterns: hardcoded credentials/tokens, embedded keys, dangerous execution functions (`eval`, `exec`, `system`), XSS sinks, insecure deserialization, and weak hashes. Findings are categorized by severity (critical / high / medium / low).

Security matching is case-insensitive for common credential/token spellings, dangerous-call matching ignores quoted literals and method-style false positives, and sensitive snippets are redacted before they are written to Markdown, JSON, SARIF, JSONL, baseline fingerprints, or manifests.

### Documentation & Context Generation
Generates standard output files plus optional security exports:

- **`FILE_TREE.md`** — Visual directory tree with file and directory markers
- **`README.md`** — Rich report with all findings
- **`llms.txt`** — Minimal project context for LLM ingestion
- **`AGENTS.md`** — AI agent instructions with routes and security notes
- **`CHECKLIST.md`** — Actionable review checklist pre-populated with findings
- **`scan_manifest.json`** — Schema-versioned run metadata and artifact pointers for automation
- **`index.json`** — Optional Kennel-compatible index payload (`schema_version`, `generated_at`, `packages`)
- **`packages/<name>.json`** — Optional Kennel-compatible package metadata payload
- **`security.sarif`** — Optional SARIF v2.1.0 security findings export
- **`security.jsonl`** — Optional JSONL security findings export

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `-o, --output DIR` | Output root directory (run writes to `DIR/<project>-<timestamp>/`) | `./results` |
| `-d, --max-depth N` | Max directory depth | `6` |
| `--skip-security` | Skip security smell scan | — |
| `--security-export F` | Emit security findings as `sarif` or `jsonl` (repeatable) | disabled |
| `--baseline PATH` | Baseline file used to suppress known findings | `scout-baseline.json` |
| `--show-suppressed` | Include suppressed findings in generated outputs | disabled |
| `--write-baseline` | Write the current finding fingerprints to the baseline file | disabled |
| `--kennel-index` | Emit a Kennel Stage 2 compatible `index.json` artifact | disabled |
| `--kennel-metadata` | Emit a Kennel Stage 2 compatible `packages/<name>.json` artifact | disabled |
| `--skip-routes` | Skip route discovery | — |
| `--skip-deps` | Skip dependency analysis | — |
| `--include PATTERN` | Include only files matching glob (repeatable) | none |
| `--exclude PATTERN` | Exclude files/directories matching glob (repeatable) | none |
| `--ignore-file PATH` | Ignore file path relative to target | `.scoutignore` |
| `--path-mode MODE` | Path style for outputs (`relative`\|`absolute`) | `relative` |
| `--output-profile P` | Output profile: `full` or `minimal` | `full` |
| `--quick` | Shortcut for `--output-profile minimal` | disabled |
| `-h, --help` | Show help | — |
| `-v, --version` | Show version | — |

## Output Structure

Each scan run creates a timestamped folder:

`<output-root>/<project-name>-YYYYMMDD-HHmmss-<epoch-ms>/`

By default this is under `./results` (inside this repository when run from repo root).

When `--quick` (or `--output-profile minimal`) is used, Scout writes a smaller artifact set focused on summary consumption:

- `README.md`
- `llms.txt`
- `intelligence.json`
- `scan_manifest.json`

## Config Semantics

Scout reads defaults from `config.json` and resolves runtime behavior with this precedence:

`CLI flags > config.json values > built-in hard defaults`

Key config sections:

- `scan`: default depth, max file size, ignored directories, include/exclude defaults
- `output`: default output directory, path mode, optional Kennel output toggles, optional security export defaults
- `analysis`: enable/disable dependency/route/security analyzers, metrics collection, and baseline visibility defaults

Common examples:

```bash
# Use config defaults as-is
kujo run scout.kujo -- ./project

# Override config depth and output at runtime
kujo run scout.kujo -- ./project -d 2 -o ./tmp/reports

# Override configured baseline path and include suppressed findings
kujo run scout.kujo -- ./project --baseline ./security/scout-baseline.json --show-suppressed
```

## Architecture

```
scout/
├── scout.kujo         # Thin CLI entrypoint that loads runtime core
├── lib/
│   ├── scout_runtime.kujo # Runtime core (CLI parse, walker, analyzers, report writers)
│   ├── path_filters.kujo # Shared slug/path/filter helpers (ARC-004 phase 1)
│   ├── sorting.kujo    # Shared deterministic sorting helpers (ARC-004 phase 2)
│   ├── security_exports.kujo # Shared security export and fingerprint helpers (ARC-004 phase 3)
│   └── text_scan.kujo   # Shared quote/scanning helpers (ARC-004 phase 4)
├── tests/
│   ├── fixtures/       # Purpose-built parser and regression fixtures
│   └── scripts/        # Executable regression scripts
├── config.json        # Default configuration
├── docs/               # Checklists and contributor process docs
└── README.md          # This file
```

Runtime entrypoint remains `scout.kujo`.

### File Responsibilities

- **`scout.kujo`**: Thin stable entrypoint (`kujo run scout.kujo -- ...`)
- **`lib/scout_runtime.kujo`**: Runtime core with CLI parsing, walker, analyzers, and report writers
- **`lib/path_filters.kujo`**: Shared slug/path/filter helpers imported by runtime core
- **`lib/sorting.kujo`**: Shared deterministic sorting helpers imported by runtime core
- **`lib/security_exports.kujo`**: Shared security export and fingerprint helpers imported by runtime core
- **`lib/text_scan.kujo`**: Shared quote/scanning helpers imported by runtime core
- **`tests/scripts/run_all_scout_tests.sh`**: One-command regression entrypoint
- **`tests/fixtures/`**: Stable fixtures for analyzer matrix and snapshot tests
- **`docs/SCOUT_EVOLUTION_CHECKLIST.md`**: Ordered implementation and work-log source of truth

## Testing

Run the full suite (including slower tests):

```bash
tests/scripts/run_all_scout_tests.sh
```

Force a non-default Kujo runtime only when needed:

```bash
KUJO_BIN=/path/to/kujo tests/scripts/run_all_scout_tests.sh
```

Run a fast path for local iteration (skips slow ARC-002 root scan):

```bash
SCOUT_SKIP_SLOW=1 tests/scripts/run_all_scout_tests.sh
```

Run focused suites:

```bash
# Route parser matrix
tests/scripts/test_test002_route_matrix.sh

# Security precision matrix
tests/scripts/test_test003_security_matrix.sh

# Golden artifact snapshots
tests/scripts/test_test005_golden_snapshots.sh
```

## Repository Reading Guide

For humans and agents scanning this repo:

- Canonical usage examples live in this README, especially Quick Start and Examples.
- `tests/fixtures/**` contains purpose-built regression fixtures; keep those explicit even when they look repetitive.
- `tests/fixtures/test005/snapshots/**` contains generated golden outputs; read them to understand contracts, not to copy style.
- `tests/tmp/**` and `results/**` are generated local outputs and should be excluded from broad cleanup/search sweeps.
- There are no known legacy, stale, or expected-fail examples in the current tree; label any future ones in-place with the reason.

## Extension Points

Most extension work happens in `lib/scout_runtime.kujo` and helper modules under `lib/`:

- Language and manifest discovery: update `LANGUAGE_MAP` and `MANIFEST_FILES`
- Route detection: extend language-specific route pattern blocks in the main scan loop
- Security detection: extend `SECURITY_PATTERNS`, redaction rules, and supporting helper logic
- New artifact outputs: add payload builders and write steps near the output section
- CLI surface area: add flags in the argument parser and mirror defaults in `config.json`

When adding new analyzers or outputs, also add:

- A fixture pair (positive/negative) under `tests/fixtures/`
- A script-level regression under `tests/scripts/`
- Checklist/work-log updates in `docs/SCOUT_EVOLUTION_CHECKLIST.md`

## Requirements

- [Kujo language](https://github.com/kujolang/kujo) runtime with `run` subcommand support (`kujo run ...`)
- Bash-compatible shell for test scripts (`tests/scripts/*.sh`)
- `jq` available in `PATH` for JSON assertions in regression scripts
- `python3` with `jsonschema` installed for schema contract validation

Scout regression scripts auto-resolve a compatible Kujo binary and will prefer `KUJO_BIN` when set.
CI pins Kujo runtime builds to tag `v0.14.0` in `.github/workflows/repo-checks.yml` for deterministic compatibility.

Run these once before local test loops:

```bash
# Kujo binary supports script execution mode
kujo run --help >/dev/null

# JSON tooling required by test scripts
jq --version

# Schema validator used by FEAT-003/005/006/007 checks
python3 -c "import jsonschema; print(jsonschema.__version__)"
```

If `jsonschema` is missing:

```bash
python3 -m pip install --user jsonschema
```

## Examples

### Minimal scan
```bash
kujo run scout.kujo -- .
```

### Deep scan of a project with full reports
```bash
kujo run scout.kujo -- ~/projects/my-app -o ./reports -d 10
```

### Quick security audit only
```bash
kujo run scout.kujo -- ./src --skip-deps --skip-routes -o ./security-audit
```

### Scan for routes only
```bash
kujo run scout.kujo -- ./api --skip-security --skip-deps -o ./api-routes
```

### Export security findings for CI tooling
```bash
kujo run scout.kujo -- ./src --security-export sarif --security-export jsonl -o ./security-audit
```

### Manage accepted findings with a baseline
```bash
# Generate or refresh baseline fingerprints
kujo run scout.kujo -- ./src --write-baseline --baseline scout-baseline.json

# Run normally with baseline suppression (default baseline path)
kujo run scout.kujo -- ./src

# Show suppressed findings for audit/debug
kujo run scout.kujo -- ./src --show-suppressed
```

### Emit a Kennel-compatible index payload
```bash
kujo run scout.kujo -- ./src --kennel-index -o ./scan-output
```

### Emit Kennel index and package metadata together
```bash
kujo run scout.kujo -- ./src --kennel-index --kennel-metadata -o ./scan-output
```

## License

MIT
