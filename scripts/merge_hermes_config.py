#!/usr/bin/env python3
"""Merge a small declarative YAML mapping into an Hermes config, preserving other settings."""
from __future__ import annotations
import argparse
import copy
import os
import sys
from pathlib import Path
import tempfile
import yaml


def merge(target: dict, fragment: dict) -> dict:
    for key, value in fragment.items():
        if isinstance(value, dict) and isinstance(target.get(key), dict):
            merge(target[key], value)
        else:
            target[key] = value
    return target


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--target', required=True, type=Path)
    parser.add_argument('--fragment', required=True, help='fragment YAML path, or - for stdin')
    args = parser.parse_args()
    existing = yaml.safe_load(args.target.read_text()) if args.target.exists() else {}
    fragment_text = sys.stdin.read() if args.fragment == '-' else Path(args.fragment).read_text()
    fragment = yaml.safe_load(fragment_text)
    if existing is None:
        existing = {}
    if not isinstance(existing, dict) or not isinstance(fragment, dict):
        raise SystemExit('Hermes config and fragment must each be YAML mappings.')
    original = copy.deepcopy(existing)
    merged = merge(existing, fragment)
    if merged == original:
        print('UNCHANGED')
        return
    fd, temporary = tempfile.mkstemp(prefix='.config.yaml.', dir=args.target.parent, text=True)
    try:
        with os.fdopen(fd, 'w') as stream:
            yaml.safe_dump(merged, stream, sort_keys=False, allow_unicode=True)
        os.chmod(temporary, 0o600)
        os.replace(temporary, args.target)
        print('CHANGED')
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == '__main__':
    main()
