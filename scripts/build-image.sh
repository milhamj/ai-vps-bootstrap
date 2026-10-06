#!/usr/bin/env bash
# Build the specialist terminal image, then remove containers still running the previous build.
# Hermes reuses its terminal containers, so without this they keep the old image until removed.
set -euo pipefail
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
setting() { python3 "$repo_dir/scripts/effective_vars.py" "$1"; }

user=${VPS_USER:-$(id -un)}
image=$(setting hermes_docker_image)
old_id=$(docker image inspect --format '{{.Id}}' "$image" 2>/dev/null || true)

docker build --platform linux/amd64 -f "$repo_dir/docker/playwright-qa/Dockerfile" \
  --build-arg "HERMES_UID=$(id -u "$user")" --build-arg "HERMES_GID=$(id -g "$user")" \
  --build-arg "AGENT_GIT_NAME=$(setting agent_git_name)" \
  --build-arg "AGENT_GIT_EMAIL=$(setting agent_git_email)" \
  -t "$image" "$repo_dir/docker/playwright-qa"

new_id=$(docker image inspect --format '{{.Id}}' "$image")
if [[ -z $old_id || $old_id == "$new_id" ]]; then
  exit 0
fi

# Only containers created from the previous build of this image; other containers are untouched.
mapfile -t stale < <(docker ps -aq --filter "ancestor=${old_id#sha256:}")
if [[ ${#stale[@]} -eq 0 ]]; then
  exit 0
fi

echo
echo "These containers still use the previous $image build:"
docker ps -a --filter "ancestor=${old_id#sha256:}" --format '  {{.ID}}  {{.Names}}  up {{.RunningFor}}'
echo 'Removing them makes Hermes start fresh ones from the new image. Files in the factory are kept;'
echo 'an agent task running in one of them right now is interrupted.'
if [[ -t 0 ]]; then
  read -rp 'Remove them now? [Y/n] ' answer
  if [[ ${answer,,} == n* ]]; then
    echo "Kept. Remove later with: docker rm -f ${stale[*]}"
    exit 0
  fi
fi
docker rm -f "${stale[@]}" >/dev/null
echo "Removed ${#stale[@]} container(s)."
