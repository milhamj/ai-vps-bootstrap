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
    models = settings["hermes_models"]
    expected_models = {
        "default": models[settings["hermes_main_model"]],
        **{
            profile["name"]: models[profile.get("model", settings["hermes_main_model"])]
            for profile in settings["hermes_profiles"]
        },
    }
    docker_image_name = settings["hermes_docker_image"]
    specialist_profiles = tuple(profile["name"] for profile in settings["hermes_profiles"])
    main_fallback = settings.get("hermes_main_fallback") or None
    expected_fallbacks = {
        "default": models[main_fallback] if main_fallback else None,
        **{
            profile["name"]: models[profile["fallback"]] if profile.get("fallback") else None
            for profile in settings["hermes_profiles"]
        },
    }
    toolsets = settings["hermes_toolsets"]
    expected_toolsets = {
        "default": toolsets["main"],
        **{
            profile["name"]: toolsets[profile.get("toolsets", "specialist")]
            for profile in settings["hermes_profiles"]
        },
    }
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
        expected_model = expected_models[name]
        if not isinstance(model, dict) or any(
            model.get(key) != expected_model[key] for key in ("default", "provider", "base_url")
        ):
            errors.append(f"{name}: model/provider/base_url do not match the configured settings")
        expected_fallback = expected_fallbacks[name]
        if expected_fallback:
            fallback = config.get("fallback_model") or {}
            if (fallback.get("provider"), fallback.get("model")) != (
                expected_fallback["provider"], expected_fallback["default"]
            ):
                errors.append(f"{name}: fallback_model does not match the configured fallback preset")
        if (config.get("proxy") or {}).get("enabled") is not False:
            errors.append(f"{name}: proxy.enabled must be false for the OAuth provider")
        if (config.get("compression") or {}).get("threshold") != 0.5:
            errors.append(f"{name}: compression.threshold must be 0.5")
        if (config.get("browser") or {}).get("cloud_provider") != "local":
            errors.append(f"{name}: browser.cloud_provider must be local")
        platform_toolsets = config.get("platform_toolsets") or {}
        for platform in ("cli", "telegram"):
            if platform_toolsets.get(platform) != expected_toolsets[name]:
                errors.append(f"{name}: platform_toolsets.{platform} does not match the configured tool set")
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
            expected_volumes = [f"{factory_root}:/workspace"]
            if settings["android_sdk"]:
                expected_volumes.append(f"{home}/.cache/hermes-gradle:/home/hermes/.gradle")
            if terminal.get("backend") != "docker":
                errors.append(f"{name}: terminal.backend must be docker")
            if terminal.get("cwd") != "/workspace":
                errors.append(f"{name}: terminal.cwd must be /workspace")
            if terminal.get("docker_image") != docker_image_name:
                errors.append(f"{name}: docker_image does not match the configured settings")
            if terminal.get("docker_mount_cwd_to_workspace") is not False:
                errors.append(f"{name}: automatic CWD mounting must be disabled")
            if terminal.get("docker_volumes") != expected_volumes:
                errors.append(f"{name}: docker_volumes must be exactly {expected_volumes}")
            if terminal.get("docker_forward_env") != settings["agent_forward_env"]:
                errors.append(f"{name}: docker_forward_env must be exactly agent_forward_env")

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
