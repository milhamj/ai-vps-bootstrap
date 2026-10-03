#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -eq 0 ]]; then
  echo 'Run this as the normal Hermes user, not root.' >&2
  exit 1
fi

if [[ -x "${HOME}/.local/bin/hermes" ]] || command -v hermes >/dev/null 2>&1; then
  echo 'Hermes is already installed. This script will not change an existing installation; run make configure instead.' >&2
  exit 1
fi

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
hermes_commit=${HERMES_COMMIT:-$(python3 "$repo_dir/scripts/effective_vars.py" hermes_commit)}
hermes_branch=$(python3 "$repo_dir/scripts/effective_vars.py" hermes_branch)
if [[ ! $hermes_commit =~ ^[0-9a-f]{40}$ ]]; then
  echo 'HERMES_COMMIT must be a full lowercase Git commit hash.' >&2
  exit 1
fi

installer=$(mktemp)
trap 'rm -f "$installer"' EXIT
installer_url="https://raw.githubusercontent.com/NousResearch/hermes-agent/${hermes_commit}/scripts/install.sh"
curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 "$installer_url" --output "$installer"
chmod 700 "$installer"
if ! /usr/bin/bash "$installer" --help 2>&1 | rg -q -- '--commit'; then
  echo 'Pinned Hermes installer does not advertise --commit; refusing an unpinned install.' >&2
  exit 1
fi
if ! /usr/bin/bash "$installer" --help 2>&1 | rg -q -- '--non-interactive'; then
  echo 'Pinned Hermes installer does not advertise --non-interactive; refusing unattended setup.' >&2
  exit 1
fi
/usr/bin/bash "$installer" --branch "$hermes_branch" --commit "$hermes_commit" --non-interactive

if [[ ! -x "${HOME}/.local/bin/hermes" ]]; then
  echo "Hermes installer finished without creating ${HOME}/.local/bin/hermes." >&2
  exit 1
fi

"${HOME}/.local/bin/hermes" --version
