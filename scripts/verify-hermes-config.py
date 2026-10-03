#!/usr/bin/env python3
"""Check Hermes profile settings and role prompts against the configured settings."""
from __future__ import annotations
import sys
from pathlib import Path

import yaml

import effective_vars


def read_mapping(path: Path) -> dict:
    if not path.is_file():
        raise ValueError(f"missing Hermes config: {path}")
    value = yaml.safe_load(path.read_text())
    if not isinstance(value, dict):
        raise ValueError(f"invalid Hermes config mapping: {path}")
    return value


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: verify-hermes-config.py HOME FACTORY_ROOT", file=sys.stderr)
        return 2
    home = Path(sys.argv[1])
    factory_root = Path(sys.argv[2])
    settings = effective_vars.load()
    expected_model = (settings["hermes_model"], settings["hermes_provider"], settings["hermes_base_url"])
    docker_image_name = settings["hermes_docker_image"]
    specialist_profiles = tuple(profile["name"] for profile in settings["hermes_profiles"])
    hermes_home = home / ".hermes"
    configs = {
        "default": read_mapping(hermes_home / "config.yaml"),
        **{
            profile: read_mapping(hermes_home / "profiles" / profile / "config.yaml")
            for profile in specialist_profiles
        },
    }
    errors: list[str] = []
    for name, config in configs.items():
        model = config.get("model", {})
        if not isinstance(model, dict) or (
            model.get("default"), model.get("provider"), model.get("base_url")
        ) != expected_model:
            errors.append(f"{name}: model/provider/base_url do not match the configured settings")
        terminal = config.get("terminal", {})
        if not isinstance(terminal, dict):
            errors.append(f"{name}: terminal settings are missing")
            continue
        if name == "default":
            if terminal.get("backend") != "local":
                errors.append("default: terminal.backend must be local")
            if terminal.get("cwd") != ".":
                errors.append("default: terminal.cwd must remain .")
        else:
            expected_volume = f"{factory_root}:/workspace"
            if terminal.get("backend") != "docker":
                errors.append(f"{name}: terminal.backend must be docker")
            if terminal.get("cwd") != "/workspace":
                errors.append(f"{name}: terminal.cwd must be /workspace")
            if terminal.get("docker_image") != docker_image_name:
                errors.append(f"{name}: docker_image does not match the configured settings")
            if terminal.get("docker_mount_cwd_to_workspace") is not False:
                errors.append(f"{name}: automatic CWD mounting must be disabled")
            if terminal.get("docker_volumes") != [expected_volume]:
                errors.append(f"{name}: docker_volumes must contain only {expected_volume}")
            if terminal.get("docker_forward_env") != []:
                errors.append(f"{name}: docker_forward_env must be empty")

    soul_paths = {
        "default": hermes_home / "SOUL.md",
        **{
            profile: hermes_home / "profiles" / profile / "SOUL.md"
            for profile in specialist_profiles
        },
    }
    for profile, path in soul_paths.items():
        if not path.is_file():
            errors.append(f"{profile}: role SOUL.md missing at {path}")

    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        return 1

    print("PASS: Hermes profile settings and role prompts are valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
