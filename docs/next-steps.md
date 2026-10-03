# Rebuild checklist

The default Hermes profile has host terminal access; the specialist profiles use Docker with the software factory mounted at `/workspace`. The factory root is `/home/<user>/software-factory`.

## First setup on a new VPS

0. If the VPS only gives you `root`, run `scripts/create-admin-user.sh <user>` as root and confirm key-based SSH login and `sudo` as that user before continuing.
1. Optionally copy `ansible/local-vars.example.yml` to `ansible/local-vars.yml` and set overrides (model provider, `git_commit_signing`, profiles).
2. Run `make install` as the normal sudo user. It disables root and password SSH login (after checking that your user has an SSH key), enables UFW with only SSH open, and starts Fail2ban. Keep your session open and confirm a new SSH login works. If a different sudo account applies the base playbook, set `VPS_USER=<user>`, then switch to `<user>` for all Hermes commands and setup.
3. Reconnect after Docker group membership changes, then run `make image-qa` as the target user to build the specialist terminal image with that user's UID/GID.
4. If Hermes is not installed, run `make hermes-install` to install the pinned `hermes_commit`. If a Hermes CLI is already installed, skip this step.
5. Run `make configure` once to create and configure the default and specialist Hermes profiles.
6. As the target user, complete Hermes model sign-in for the profiles that need it. Complete messaging setup for the profiles that should receive messages (the main profile and those with `gateway: true` in `hermes_profiles`; by default `hoe`), then install their gateway services with Hermes CLI.
7. Run `make configure` again to apply managed profile settings after the interactive setup and restart any gateway services that were already active.
8. Run `make verify`.
9. Restore Git identity, GitHub credentials, repositories, and required backups. If `git_commit_signing` is enabled, also restore or generate the GPG private key and trust configuration for host commits. Signed commits from specialist Docker terminals need a separately designed key/agent arrangement; do not mount the host GPG material into the container by default.
10. Verify provider sign-in, `sudo ufw status verbose`, `sudo fail2ban-client status sshd`, the gateway services, a positive factory read/write, and a negative test that a specialist profile cannot access paths outside the mounted workspace.

## Still needed for a full rebuild

- For byte-for-byte image rebuilds, a snapshot of the OS package repositories used by `playwright install --with-deps`. The base image is pinned by digest, but those package repositories are not immutable.
- Whether to restore existing Git signing keys or create fresh keys. Never send private keys or passphrases.
- Backup/restore choices for repositories, Hermes state, OAuth sessions, messaging configuration, and other persistent data.
- A full run including `make hermes-install` and Hermes sign-in. CI (`.github/workflows/ci.yml`) covers install, configure, the QA image, and verify on Ubuntu 24.04, but not Hermes itself.

The model, provider, base URL, Docker image name, and profiles are set in `ansible/vars.yml` (overridable in `ansible/local-vars.yml`); workflows and agent guidance live in `config/software-factory/`. Keep tokens, private keys, passphrases, recovery codes, and other secret values out of notes and config exports.

The playbook moves `/home/<user>/projects/software-factory` to `/home/<user>/software-factory` when only the old path exists. If both paths already exist, it stops without merging either directory; back them up and reconcile them before rerunning setup.
