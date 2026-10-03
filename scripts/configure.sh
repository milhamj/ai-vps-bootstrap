#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
target_user=${VPS_USER:-$(id -un)}
if [[ ${EUID} -eq 0 || ${target_user} == root ]]; then echo 'Run as a normal sudo user, not root.' >&2; exit 1; fi
if ! id "${target_user}" >/dev/null 2>&1; then echo 'VPS_USER must already exist.' >&2; exit 1; fi
if ! command -v ansible-playbook >/dev/null; then echo 'Install Ansible first: make install' >&2; exit 1; fi
local_vars=()
if [[ -f "${repo_dir}/ansible/local-vars.yml" ]]; then
  local_vars=(--extra-vars "@${repo_dir}/ansible/local-vars.yml")
fi
sudo -v
ansible-playbook -i "${repo_dir}/ansible/inventory/localhost.yml" \
  "${repo_dir}/ansible/playbook.yml" "${local_vars[@]}" --extra-vars "factory_user=${target_user}"
