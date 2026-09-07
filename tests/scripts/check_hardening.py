"""Behavioral checks for scan boundaries and failure semantics; no timing gates."""
import json
import os
import pathlib
import random
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
WORK = ROOT / "tests/tmp/hardening"
shutil.rmtree(WORK, ignore_errors=True)
WORK.mkdir(parents=True)
KUJO = str(pathlib.Path(sys.argv[1]).resolve())
failures = []


def check(condition, message):
    if not condition:
        failures.append(message)


def scan(target, label, *options, cwd=ROOT):
    output = WORK / (label + "-output")
    result = subprocess.run(
        [KUJO, "run", str(ROOT / "scout.kujo"), str(target), "-o", str(output), *options],
        cwd=cwd, capture_output=True, text=True, timeout=60,
    )
    (WORK / (label + ".log")).write_text(result.stdout + result.stderr)
    if result.returncode:
        return result, None, None
    manifests = list(output.glob("*/scan_manifest.json"))
    assert len(manifests) == 1, label
    directory = manifests[0].parent
    return result, json.loads((directory / "intelligence.json").read_text()), directory


project = WORK / "project"
project.mkdir()
sibling = WORK / "project "
sibling.mkdir()
(sibling / "outside.py").write_text("import outside_boundary_marker\n")
(project / "escape").symlink_to(sibling, target_is_directory=True)
(project / " space ").mkdir()
(project / " space " / "inside.py").write_text("import inside_boundary_marker\n")
result, data, _ = scan(project, "paths")
check(result.returncode == 0, "path scan must succeed")
if data:
    check(not any(d["module"] == "outside_boundary_marker" for d in data["dependencies"]),
          "whitespace sibling symlink escapes target")
    check(any(d["source"] == " space /inside.py" for d in data["dependencies"]),
          "source path whitespace must remain exact")

(project / "broken").symlink_to(WORK / "does-not-exist")
os.mkfifo(project / "pipe.py")
(project / "z_after.py").write_text("import after_broken_marker\n")
result, data, _ = scan(project, "unavailable")
check(result.returncode == 0, "unavailable entries must not abort the remaining scan")
if data:
    check(any(d["module"] == "after_broken_marker" for d in data["dependencies"]),
          "broken symlink prevented sibling analysis")
    check(any(d["error"] == "path_unavailable" for d in data["parse_errors"]),
          "unavailable entry must have a structured diagnostic")
    check(any(d["file"] == "broken" for d in data["parse_errors"]),
          "entry diagnostic must respect relative path mode")
    check("Scan diagnostics" in result.stdout, "partial scan must have a concise diagnostic receipt")

cycle = WORK / "cycle"
cycle.mkdir()
(cycle / "app.py").write_text("import cycle_marker\n")
(cycle / "loop").symlink_to(cycle, target_is_directory=True)
result, data, _ = scan(cycle, "cycle", "-d", "2")
check(result.returncode == 0, "cycle handling must preserve the scan")
if data:
    check(data["metrics"]["total_files"] == 1, "directory cycle reanalyzed the same source")
    check(any(d["error"] == "directory_cycle" for d in data["parse_errors"]),
          "directory cycle must be diagnosed")

secrets = WORK / "secrets"
secrets.mkdir()
(secrets / "app.py").write_text(
    'password = "hardening-secret-one"; eval(user_input)\n'
    'consume("hardening-secret-two", password = supplied)\n'
    'token = "hardening-secret-three"; digest = hashlib.md5(data)\n'
)
result, data, directory = scan(secrets, "redaction", "--security-export", "sarif",
                               "--security-export", "jsonl", "--write-baseline")
check(result.returncode == 0, "redaction scan must succeed")
if data:
    check(len(data["security_findings"]) == 5, "redaction must preserve all five findings")
    texts = [p.read_text() for p in directory.rglob("*") if p.is_file()]
    texts.append((secrets / "scout-baseline.json").read_text())
    check(all("hardening-secret-" not in text for text in texts),
          "sensitive line leaks through another rule or unsafe prefix")

manifests = WORK / "manifests"
manifests.mkdir()
(manifests / "package.json").write_text('''{
  "dependencies": {},
  "description": "not a dependency",
  "scripts": {"test": "not a dependency"},
  "metadata": {
    "dependencies": {
      "fake": "1"
    }
  },
  "devDependencies": {"real": "1"}
}
''')
(manifests / "composer.json").write_text('''{
  "require": {},
  "description": "not a dependency",
  "require-dev": {"vendor/real": "1"}
}
''')
result, data, _ = scan(manifests, "manifests")
check(result.returncode == 0, "manifest scan must succeed")
if data:
    check({d["module"] for d in data["dependencies"]} == {"real", "vendor/real"},
          "valid structured JSON must not gain dependencies from the fallback parser")

# A regular file cannot be walked as a directory; success would hide the failure.
result, _, _ = scan(manifests / "package.json", "file-target")
check(result.returncode != 0 and "directory" in result.stdout + result.stderr,
      "regular-file target must fail with an actionable diagnostic")

# Config failure checks use an isolated working directory, never edit repo defaults.
config_cwd = WORK / "config"
config_cwd.mkdir()
for field, value in (("max_file_size", -1), ("max_file_size", "garbage"),
                     ("default_max_depth", 1.5)):
    (config_cwd / "config.json").write_text(json.dumps({"scan": {field: value}}))
    result, _, _ = scan(manifests, "invalid-" + field, cwd=config_cwd)
    check(result.returncode != 0 and field in result.stdout + result.stderr,
          "invalid " + field + " must fail before scanning")

blocked_output = WORK / "blocked-output"
blocked_output.write_text("preserve this file")
result, _, _ = scan(manifests, "blocked")
check(result.returncode != 0 and "output root" in result.stdout + result.stderr,
      "output creation failure must be actionable")
check(blocked_output.read_text() == "preserve this file", "failed output clobbered existing file")

# Stable ordering, numeric security lines, delimiter keys, and non-mutation.
rng = random.Random(701)
for count in (0, 1, 33):
    records = [{"module": rng.choice(["z", "a|b", "a", "é"]),
                "type": "module", "source": "src/main.py", "method": "GET",
                "path": rng.choice(["/z", "/a", "/"]),
                "severity": rng.choice(["critical", "high", "medium", "low"]),
                "file": "app.py", "line": rng.choice([2, 10, 100]),
                "label": rng.choice(["A", "Z"]), "sequence": i} for i in range(count)]
    payload = {"dependencies": records, "routes": records, "security": records,
               "strings": [r["module"] for r in records]}
    source = WORK / "sort-input.json"
    source.write_text(json.dumps(payload))
    result = subprocess.run([KUJO, "run", "tests/fixtures/hardening/sort_contract.kujo", str(source)],
                            cwd=ROOT, capture_output=True, text=True, timeout=60, check=True)
    ordered = json.loads(result.stdout)
    check(ordered["original"] == payload, "sorting mutated input")
    check(ordered["strings"] == sorted(payload["strings"]), "string ordering changed")
    for key, fields in (("dependencies", ("module", "type", "source")),
                        ("routes", ("method", "path", "source"))):
        check(ordered[key] == sorted(records, key=lambda r: "|".join(r[f] for f in fields)),
              key + " ordering or stability changed")
    rank = {"critical": 0, "high": 1, "medium": 2, "low": 3}
    check(ordered["security"] == sorted(records, key=lambda r:
          (rank[r["severity"]], r["file"], r["line"], r["label"])),
          "security ordering or stability changed")

for message in failures:
    print("FAIL:", message)
if failures:
    sys.exit(1)
print("Hardening boundary, redaction, manifest, and failure checks passed")
