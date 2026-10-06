#!/usr/bin/env bash
# Set API keys for every Hermes profile whose model preset uses an API-key provider.
# Each key is asked for once (hidden input, never in shell history) and set on each such profile
# with `<profile> config set`. Usage: scripts/set-provider-keys.sh [--check]
set -euo pipefail
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
bin_dir="$HOME/.local/bin"

# Lines of "<profile command> <key variable>" for profiles that need an API key.
needs_keys() {
  python3 - "$repo_dir/scripts" <<'EOF'
import sys
sys.path.insert(0, sys.argv[1])
import effective_vars
# API-key providers and the variable Hermes reads the key from. OAuth providers
# such as openai-codex sign in with `hermes setup` instead.
KEY_VARS = {"openrouter": "OPENROUTER_API_KEY"}
s = effective_vars.load()
models, main = s["hermes_models"], s["hermes_main_model"]
profiles = [("hermes", main)] + [(p["name"], p.get("model", main)) for p in s["hermes_profiles"]]
for command, model in profiles:
    var = KEY_VARS.get(models[model]["provider"])
    if var:
        print(command, var)
EOF
}

has_key() { [[ -n $("$bin_dir/$1" config get "$2" 2>/dev/null) ]]; }

mapfile -t entries < <(needs_keys)
if [[ ${#entries[@]} -eq 0 ]]; then
  echo 'No profile uses an API-key provider; nothing to set.'
  exit 0
fi

missing=0
for entry in "${entries[@]}"; do
  read -r profile var <<<"$entry"
  if has_key "$profile" "$var"; then state='set'; else state='missing'; missing=1; fi
  printf '  %-10s %-20s %s\n' "$profile" "$var" "$state"
done
if [[ ${1:-} == --check ]]; then
  exit "$missing"
fi

for var in $(printf '%s\n' "${entries[@]}" | awk '{print $2}' | sort -u); do
  read -rsp "Value for $var (empty to keep current values): " value
  echo
  [[ -z $value ]] && continue
  for entry in "${entries[@]}"; do
    read -r profile entry_var <<<"$entry"
    [[ $entry_var == "$var" ]] || continue
    "$bin_dir/$profile" config set "$var" "$value" >/dev/null
    echo "  set $var for $profile"
  done
done
unset value
