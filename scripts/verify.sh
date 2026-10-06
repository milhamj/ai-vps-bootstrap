#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source /etc/os-release
[[ ${ID:-} == ubuntu && ${VERSION_ID:-} == 24.04 ]] || { echo 'FAIL: Ubuntu 24.04 required'; exit 1; }
for tool in git ansible-playbook docker rg jq tmux python3; do
  command -v "$tool" >/dev/null || { echo "FAIL: $tool missing"; exit 1; }
done
systemctl is-active --quiet docker || { echo 'FAIL: Docker inactive'; exit 1; }
docker compose version >/dev/null || { echo 'FAIL: Docker Compose v2 missing'; exit 1; }

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
setting() { python3 "$repo_dir/scripts/effective_vars.py" "$1"; }
is_true() { [[ ${1,,} =~ ^(true|yes|on|1)$ ]]; }
target_user=${VPS_USER:-$(id -un)}
target_home=$(getent passwd "$target_user" | cut -d: -f6)
factory_root="$target_home/$(setting factory_relative_path)"
[[ -n $target_home && -d "$factory_root/projects" ]] || { echo 'FAIL: software factory missing'; exit 1; }
if is_true "$(setting git_commit_signing)"; then
  git_signing=$(HOME="$target_home" git config --global --get commit.gpgsign || true)
  git_format=$(HOME="$target_home" git config --global --get gpg.format || true)
  [[ $git_signing == true && $git_format == gpg ]] || {
    echo 'FAIL: git_commit_signing is enabled but host Git signing preferences are missing' >&2
    exit 1
  }
fi

if is_true "$(setting ssh_hardening)"; then
  [[ -f /etc/ssh/sshd_config.d/00-ai-vps-hardening.conf ]] || {
    echo 'FAIL: ssh_hardening is enabled but the sshd hardening file is missing; run make configure' >&2
    exit 1
  }
fi
if is_true "$(setting firewall_enabled)"; then
  grep -qx 'ENABLED=yes' /etc/ufw/ufw.conf 2>/dev/null || { echo 'FAIL: UFW firewall is not enabled' >&2; exit 1; }
fi
if is_true "$(setting fail2ban_enabled)"; then
  systemctl is-active --quiet fail2ban || { echo 'FAIL: Fail2ban is not running' >&2; exit 1; }
fi

if ! docker info >/dev/null 2>&1; then
  echo 'FAIL: Docker CLI cannot reach daemon as this user; re-login after group changes before verifying.' >&2
  exit 1
fi

docker_image=$(setting hermes_docker_image)
docker image inspect "$docker_image" >/dev/null 2>&1 || {
  echo "FAIL: specialist terminal image $docker_image is missing; run make image-qa" >&2
  exit 1
}
probe="/workspace/.hermes-terminal-write-probe-$$"
docker run --rm --workdir /workspace --volume "$factory_root:/workspace" "$docker_image" \
  /bin/sh -c "test -r /workspace && test -w /workspace && : > $probe && rm -- $probe" >/dev/null 2>&1 || {
  echo 'FAIL: the terminal image cannot read and write the factory mount; rebuild with make image-qa as the target user so its UID/GID match.' >&2
  exit 1
}

docker run --rm "$docker_image" gh --version >/dev/null 2>&1 || {
  echo 'FAIL: terminal image has no GitHub CLI (gh); run make image-qa' >&2
  exit 1
}
for key in name email; do
  expected=$(setting "agent_git_$key")
  [[ -z $expected ]] && continue
  actual=$(docker run --rm "$docker_image" git config --system --get "user.$key" 2>/dev/null || true)
  [[ $actual == "$expected" ]] || {
    echo "FAIL: terminal image git user.$key is '$actual', expected '$expected'; run make image-qa" >&2
    exit 1
  }
done

hermes_cli="$target_home/.local/bin/hermes"
if [[ -x $hermes_cli ]]; then
  hermes_commit=$(git -C "$target_home/.hermes/hermes-agent" rev-parse HEAD)
  expected_commit=$(setting hermes_commit)
  [[ $hermes_commit == "$expected_commit" ]] || {
    echo "FAIL: Hermes commit $hermes_commit differs from configured commit $expected_commit" >&2
    exit 1
  }
  python3 "$repo_dir/scripts/verify-hermes-config.py" "$target_home" "$factory_root"
else
  echo 'NOTE: Hermes is not installed yet; profile configuration checks are pending.'
fi

echo 'PASS: Ubuntu, base tools, Docker service, Compose, software factory, and terminal image are ready.'
