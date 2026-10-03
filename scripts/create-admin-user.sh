#!/usr/bin/env bash
# Create a non-root sudo user for a VPS that only provides root, and give it root's SSH keys.
# Run as root once, before make install. Usage: sudo ./scripts/create-admin-user.sh <user>
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then echo 'Run this as root.' >&2; exit 1; fi
if [[ $# -ne 1 ]]; then echo "Usage: $0 <user>" >&2; exit 2; fi
user=$1
if [[ ! $user =~ ^[a-z_][a-z0-9_-]*$ || $user == root ]]; then
  echo "Invalid user name: $user" >&2
  exit 1
fi

if id "$user" >/dev/null 2>&1; then
  echo "User $user already exists; keeping its password."
else
  # Prompts for a password. sudo asks for it; SSH login will use keys only.
  adduser --gecos '' "$user"
fi
usermod -aG sudo "$user"

home=$(getent passwd "$user" | cut -d: -f6)
group=$(id -gn "$user")
keys="$home/.ssh/authorized_keys"
install -d -m 700 -o "$user" -g "$group" "$home/.ssh"
if [[ -s $keys ]]; then
  echo "$keys already exists; leaving it unchanged."
elif [[ -s /root/.ssh/authorized_keys ]]; then
  install -m 600 -o "$user" -g "$group" /root/.ssh/authorized_keys "$keys"
  echo "Copied root's SSH keys to $keys."
else
  echo "WARNING: root has no SSH keys to copy. Add your public key to $keys before make install," >&2
  echo "         or make install will refuse to disable password login." >&2
fi

cat <<EOF

Next steps:
  1. Keep this session open. From your own machine, in a new terminal: ssh $user@<server>
  2. In that session, check sudo works: sudo whoami   (expect: root)
  3. Clone this repository as $user and run make install from there.
     make install disables root and password SSH login.
EOF
