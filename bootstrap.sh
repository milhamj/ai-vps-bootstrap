#!/usr/bin/env bash
set -euo pipefail
if [[ ${EUID} -eq 0 ]]; then echo 'Run as a normal sudo user, not root.' >&2; exit 1; fi
if [[ ! -r /etc/os-release ]]; then echo 'Missing /etc/os-release.' >&2; exit 1; fi
# shellcheck disable=SC1091
source /etc/os-release
if [[ ${ID:-} != ubuntu || ${VERSION_ID:-} != 24.04 ]]; then echo 'Requires Ubuntu 24.04.' >&2; exit 1; fi
if ! sudo -v; then echo 'sudo access is required.' >&2; exit 1; fi
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ansible git
if ! apt-cache show docker-compose-v2 >/dev/null 2>&1; then
  echo 'docker-compose-v2 is unavailable. Enable Ubuntu universe in apt sources, then retry.' >&2
  exit 1
fi
exec "$(dirname "$0")/scripts/configure.sh"
