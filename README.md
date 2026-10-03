# VPS bootstrap (Ubuntu 24.04)

A reproducible bootstrap for running a [Hermes Agent](https://github.com/NousResearch/hermes-agent) "software factory" on an Ubuntu 24.04 VPS. It installs baseline tools and Docker, creates `/home/<user>/software-factory`, installs a pinned Hermes revision on request, and configures a default Hermes profile plus specialist agent profiles (Head of Engineering, Tech Lead, Engineer, QA) that work through Docker-sandboxed terminals.

## Prerequisites

- A fresh Ubuntu 24.04 VPS with a non-root sudo user and working SSH access.
- Back up any existing data before applying to a machine that is not fresh.
- Review `ansible/vars.yml`, especially `docker_group_access`. Membership in the Docker group grants broad control of the host.
- The default model settings use the `openai-codex` provider, which signs in with a ChatGPT account. Override `hermes_model`, `hermes_provider`, and `hermes_base_url` to use a different provider.

## Settings

Defaults live in `ansible/vars.yml`. To override them without editing tracked files, copy `ansible/local-vars.example.yml` to `ansible/local-vars.yml` (gitignored) and uncomment the keys you want to change. Each top-level key replaces the default; lists are replaced, not merged. `make configure`, `make verify`, `make hermes-install`, and `make image-qa` all read the same combined settings through `scripts/effective_vars.py`.

Notable settings:

- `git_commit_signing` (default `false`): set to `true` to require GPG-signed commits for the target user. You must restore or generate a GPG key yourself.
- `hermes_profiles`: the specialist profiles. Each entry has a `name` (the Hermes profile and CLI alias), a `role` (the folder under `config/software-factory/agents/` holding its `SOUL.md`), and an optional `gateway: true` for profiles you message directly. By default only the main profile and `hoe` have gateways; the other specialists are reached through the factory workflow. To add a profile, add an entry and a matching `SOUL.md`; profile creation, settings, role prompts, gateway restarts, and verification all follow the list.

The target user is not a setting: it is the user running the commands, or `VPS_USER=<user>` when a different sudo account applies the playbook. Credentials never go in these files; configure them through Hermes setup on the VPS.

## First setup

Run these as the normal sudo user:

```bash
make install
```

If the playbook added the user to the Docker group, close the SSH session and reconnect so the new group membership takes effect. Then continue as `<user>`:

```bash
if [[ ! -x "$HOME/.local/bin/hermes" ]]; then make hermes-install; fi
make configure
~/.local/bin/hermes setup
~/.local/bin/hoe setup
~/.local/bin/techlead setup
~/.local/bin/engineer setup
~/.local/bin/qa setup
~/.local/bin/hermes gateway setup
~/.local/bin/hoe gateway setup
~/.local/bin/hermes gateway install
~/.local/bin/hoe gateway install
make configure
make image-qa
make verify
```

The commands above match the default `hermes_profiles`; adjust the `setup` lines if you change the list. Run `make image-qa` as the target user (or with `VPS_USER=<user>`) so the image runs with that user's UID/GID.

Complete the interactive model sign-in and messaging setup directly on the VPS. Specialist profiles have separate Hermes profile state; configure credentials required by each profile. Do not put credentials in this repository or send them in chat.

The workflow setup commands are interactive. If you already restored valid profile state and gateway units, run `make configure` and `make verify`. Run Hermes installation, setup, and gateway commands while logged in as `<user>` so its profiles and services belong to the intended user. If a different sudo account applies the base playbook, use `VPS_USER=<user> make install`, then switch to `<user>` for the Hermes commands. Do not run `make install` as root.

On a fresh VPS without Hermes, `make hermes-install` pins the application source to the `hermes_commit` setting (Hermes v0.21.2 by default). It downloads the installer script from that immutable commit and refuses to run when Hermes is already installed. If a Hermes CLI is already present, skip the install command and run `make configure`.

## Commands

- `make install`: install OS prerequisites and apply the base playbook.
- `make hermes-install`: install the pinned Hermes source revision when no Hermes CLI is present.
- `make configure`: apply the workspace and managed Hermes configuration again.
- `make image-qa`: build the Playwright terminal image used by the specialist profiles, owned by the target user's UID/GID.
- `make verify`: verify the host, workspace, Hermes settings, and required specialist Docker image.
- `make update`: fetch nothing automatically; run `git pull --ff-only` yourself, review the diff, then `make configure`.

## Target layout and access

The factory root is `/home/<user>/software-factory`. If only an older-layout directory `/home/<user>/projects/software-factory` exists, the playbook moves it to the new path and preserves its contents. If both paths exist, it stops so you can reconcile them without overwriting either one. Projects are kept under `projects/<project-name>/`; repositories and required docs are organized as described in its `AGENTS.md` and `WORKFLOW.md`.

The default Hermes profile uses the `local` terminal backend and runs as the configured Unix user. Specialist profiles use the `docker` terminal backend, start in `/workspace`, and receive only the read-write mount `/home/<user>/software-factory:/workspace`. Automatic CWD mounting is disabled and no host environment variables are forwarded.

The container volume list scopes the specialist terminal environment. The gateway process itself runs as the configured Unix user. Each Hermes profile has separate configuration and session state.

## Machine-specific dependencies

The Playwright image build file is included under `docker/playwright-qa/`. Run `make image-qa` before using specialist terminal calls; `make verify` checks for the image and that it can write to the factory. The upstream base image is pinned by digest; OS packages installed during the build are not, so rebuilds are not guaranteed to be byte-for-byte identical. When `git_commit_signing` is enabled, the playbook sets host Git signing preferences, but a GPG key must be restored or generated before signed commits can succeed. Docker packages follow the Ubuntu 24.04 repository and are not pinned to package snapshots. GitHub authentication and backup restoration are documented in `docs/next-steps.md`.

## Agent guidance

`config/software-factory/` contains the shared `AGENTS.md`, `WORKFLOW.md`, and role-specific `SOUL.md` files. Ansible installs shared guidance in the factory (rendering the factory path into `AGENTS.md`) and each role prompt into its Hermes profile. The role list in `AGENTS.md` is prose; update it if you change `hermes_profiles`. QA is named Diana.
