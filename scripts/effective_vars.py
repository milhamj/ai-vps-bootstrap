#!/usr/bin/env python3
"""Resolve settings from ansible/vars.yml overlaid with the optional ansible/local-vars.yml.

Top-level keys in local-vars.yml replace those in vars.yml, matching Ansible's default
variable precedence for --extra-vars. Usage: effective_vars.py KEY
Prints booleans as true/false and lists space-separated, for use from shell scripts.
"""
from __future__ import annotations
import sys
from pathlib import Path

import yaml

ANSIBLE_DIR = Path(__file__).resolve().parent.parent / "ansible"


def _read(path: Path) -> dict:
    if not path.is_file():
        return {}
    value = yaml.safe_load(path.read_text())
    if value is None:
        return {}
    if not isinstance(value, dict):
        raise SystemExit(f"{path} must be a YAML mapping.")
    return value


def load() -> dict:
    return {**_read(ANSIBLE_DIR / "vars.yml"), **_read(ANSIBLE_DIR / "local-vars.yml")}


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: effective_vars.py KEY", file=sys.stderr)
        return 2
    settings = load()
    key = sys.argv[1]
    if key not in settings:
        print(f"unknown setting: {key}", file=sys.stderr)
        return 1
    value = settings[key]
    if isinstance(value, bool):
        print(str(value).lower())
    elif isinstance(value, list):
        print(" ".join(str(item) for item in value))
    else:
        print(value)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
