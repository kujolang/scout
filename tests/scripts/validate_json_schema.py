#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path

try:
    from jsonschema import Draft202012Validator
except Exception as exc:  # pragma: no cover
    print(
        "jsonschema dependency is required. Install with: python3 -m pip install jsonschema",
        file=sys.stderr,
    )
    print(f"Import error: {exc}", file=sys.stderr)
    sys.exit(1)


def validate_object(instance, schema, label):
    validator = Draft202012Validator(schema)
    errors = sorted(validator.iter_errors(instance), key=lambda err: list(err.path))
    if errors:
        print(f"Schema validation failed for {label}", file=sys.stderr)
        for err in errors:
            path = ".".join(str(part) for part in err.path)
            path_text = path if path else "<root>"
            print(f"  - {path_text}: {err.message}", file=sys.stderr)
        return False

    return True


def main():
    parser = argparse.ArgumentParser(description="Validate JSON/JSONL against a JSON Schema")
    parser.add_argument("--schema", required=True, help="Path to JSON Schema file")
    parser.add_argument("--instance", required=True, help="Path to JSON or JSONL file")
    parser.add_argument(
        "--jsonl",
        action="store_true",
        help="Treat instance as JSONL and validate each non-empty line as one document",
    )
    args = parser.parse_args()

    schema_path = Path(args.schema)
    instance_path = Path(args.instance)

    if not schema_path.exists():
        print(f"Schema file not found: {schema_path}", file=sys.stderr)
        return 1
    if not instance_path.exists():
        print(f"Instance file not found: {instance_path}", file=sys.stderr)
        return 1

    schema = json.loads(schema_path.read_text(encoding="utf-8"))

    if args.jsonl:
        ok = True
        line_count = 0
        for idx, raw_line in enumerate(instance_path.read_text(encoding="utf-8").splitlines(), start=1):
            line = raw_line.strip()
            if not line:
                continue
            line_count += 1
            try:
                obj = json.loads(line)
            except json.JSONDecodeError as err:
                print(f"Invalid JSON on line {idx}: {err}", file=sys.stderr)
                return 1
            ok = validate_object(obj, schema, f"{instance_path} line {idx}") and ok

        if line_count == 0:
            print(f"No JSONL records found in {instance_path}", file=sys.stderr)
            return 1

        return 0 if ok else 1

    instance = json.loads(instance_path.read_text(encoding="utf-8"))
    return 0 if validate_object(instance, schema, str(instance_path)) else 1


if __name__ == "__main__":
    sys.exit(main())
