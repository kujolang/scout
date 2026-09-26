#!/usr/bin/env python3
"""Offline deterministic contract test for schema-lock rendering."""

import hashlib
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tests/scripts/refresh_schema_lock.py"

with tempfile.TemporaryDirectory(prefix="scout-lock-test-") as temp_name:
    temp = Path(temp_name)
    seed = temp / "requirements.in"
    seed.write_text("alpha-package==1.0.0\nbeta==2.0\n")
    wheels = temp / "wheels"
    wheels.mkdir()
    contents = {"alpha_package-1.0.0-py3-none-any.whl": b"alpha",
                "beta-2.0-py3-none-any.whl": b"beta"}
    for name, content in contents.items():
        (wheels / name).write_bytes(content)
    output = temp / "requirements.txt"
    command = [sys.executable, str(SCRIPT), "--input", str(seed), "--output", str(output), "--wheel-dir", str(wheels)]
    subprocess.run(command, check=True)
    subprocess.run(command + ["--check"], check=True)
    rendered = output.read_text()
    for content in contents.values():
        assert hashlib.sha256(content).hexdigest() in rendered
    output.write_text(rendered.replace("sha256:", "sha256:0", 1))
    stale = subprocess.run(command + ["--check"], capture_output=True)
    assert stale.returncode != 0
print("Schema lock refresh contract passed")
