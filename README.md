# VPS bootstrap (Ubuntu 24.04)

A reproducible bootstrap for running a [Hermes Agent](https://github.com/NousResearch/hermes-agent) "software factory" on an Ubuntu 24.04 VPS. It installs baseline tools and Docker, creates `/home/<user>/software-factory`, installs a pinned Hermes revision on request, and configures a default Hermes profile plus specialist agent profiles (Head of Engineering, Tech Lead, Engineer, QA) that work through Docker-sandboxed terminals. It also hardens the server: key-only SSH, a UFW firewall, and Fail2ban.

## How it works

You talk to the Head of Engineering (`hoe`) over Telegram. It turns your request into a requirement and a high-level design, asks for your approval, then hands the work through Hermes Kanban to the specialist profiles. A second approval gate comes before anything is merged. The main Hermes profile is also reachable over Telegram for general tasks on the host.

```mermaid
flowchart TD
    you([You, on Telegram]) --> hoe[Head of Engineering<br/>hoe]
    hoe --> req[Requirement + high-level design<br/>docs/requirements, docs/architecture]
    req --> gate1{{Approval gate 1:<br/>you approve the requirement}}
    gate1 --> kanban[(Hermes Kanban)]
    kanban --> tl[Tech Lead<br/>implementation plan<br/>docs/implementation]
    tl --> eng[Engineer<br/>implementation + tests]
    eng --> review[Tech Lead review]
    review -- changes required --> eng
    review --> qa[QA<br/>verifies against the requirement<br/>docs/qa]
    qa -- fail --> eng
    qa --> gate2{{Approval gate 2:<br/>you approve the result}}
    gate2 --> merge([Ready to merge])
```

The specialists run their commands in Docker containers that can only see the factory folder. Project state lives in durable artifacts (Markdown docs, Kanban tasks, Git history, QA reports) rather than in chat history, so work survives restarts and agent failures. The full lifecycle and handoff rules are in `config/software-factory/WORKFLOW.md`.

## Prerequisites

- A fresh Ubuntu 24.04 VPS with a non-root sudo user who can log in with an SSH key. If your provider only gives you `root`, run `scripts/create-admin-user.sh <user>` as root first (see below).
- Back up any existing data before applying to a machine that is not fresh.
- Review `ansible/vars.yml`, especially `docker_group_access`. Membership in the Docker group grants broad control of the host.
- By default the main profile uses `gpt-5.6-sol` through the `openai-codex` provider (a ChatGPT subscription); `techlead` uses `z-ai/glm-5.3`, and `hoe`, `engineer`, and `qa` use the cheaper `z-ai/glm-5.3-flash`, all through OpenRouter (an OpenRouter API key with credits). Change this with `hermes_models`, `hermes_main_model`, and each profile's `model`.

## Settings

Defaults live in `ansible/vars.yml`. To override them without editing tracked files, copy `ansible/local-vars.example.yml` to `ansible/local-vars.yml` (gitignored) and uncomment the keys you want to change. Each top-level key replaces the default; lists are replaced, not merged. `make configure`, `make verify`, `make hermes-install`, and `make image-qa` all read the same combined settings through `scripts/effective_vars.py`.

Notable settings:

- `ssh_hardening` (default `true`): disables SSH root login and password login. Before changing anything, it checks that the target user (and the user running the playbook) has a public key in `~/.ssh/authorized_keys`, and stops with an error if not. It then confirms the effective sshd settings with `sshd -T`.
- `ssh_password_login` (default `false`): set to `true` to keep password login for non-root users, for example to log in from devices without your SSH key. Root login stays blocked, the key check is skipped, and Fail2ban still bans repeated failed attempts. Use a strong password.
- `firewall_enabled` (default `true`) and `ssh_port` (default `22`): UFW denies incoming traffic except SSH on `ssh_port` and allows outgoing traffic. `ssh_port` only opens the firewall; it does not change the port sshd listens on. Setting `firewall_enabled: false` leaves UFW as it is rather than disabling it.
- `fail2ban_enabled` (default `true`): Fail2ban with an sshd jail that reads the systemd journal.
- `git_commit_signing` (default `false`): set to `true` to require GPG-signed commits for the target user. You must restore or generate a GPG key yourself.
- `hermes_models` and `hermes_main_model`: named model presets (`default` model, `provider`, `base_url`) and the one the main profile uses. Each entry in `hermes_profiles` picks a preset with `model:` (default: `hermes_main_model`). Sign in to `openai-codex` with `hermes setup`. API keys for OpenRouter are set on each profile that uses it by `make provider-keys`, which asks for the key once (hidden) and runs `<profile> config set OPENROUTER_API_KEY` for each; `make verify` fails if one is missing. Run it again after adding a profile or changing a model preset.
- `agent_git_name` and `agent_git_email` (default empty): the Git identity for commits the agents make in their Docker terminals (`hoe`, `techlead`, `engineer`, `qa`). It is built into the terminal image, so run `make image-qa` after changing it, and written into the factory `AGENTS.md` (Commit conventions) so every agent, including the main profile on the host, commits as it; run `make configure` after changing it. While empty, agent commits fail with Git's "Please tell me who you are". The main profile runs on the host and uses your own Git config.
- `agent_forward_env` (default empty): names of variables passed from each specialist profile's `.env` into its Docker terminal, for example `[GH_TOKEN]`. See [GitHub access for agents](#github-access-for-agents).
- `android_sdk` (default `false`): add the Android toolchain to the terminal image. See [Android builds](#android-builds).
- `agent_commit_trailers` (default empty): trailer lines, such as `Co-Authored-By: …`, that every agent commit message must end with. When set, the Commit conventions section of the factory `AGENTS.md` lists them. It is an instruction to the agents, not an enforced Git hook.
- `hermes_main_fallback` (default `glm-flash`): the preset the main profile switches to when its model fails, for example when the ChatGPT subscription hits its limit. Written as Hermes `fallback_model`. Profiles can set their own with `fallback:`. `make provider-keys` also covers fallback providers, so the main profile gets an OpenRouter key for it. Set it to `''` to disable; Hermes then keeps any `fallback_model` already in the profile, so remove that by hand.
- `hermes_toolsets`: the Hermes tools enabled for each profile's `cli` and `telegram` platforms. `main` (default and `hoe`) adds delegation, connections, vision, cronjob, and image_gen; `specialist` (the Kanban workers) leaves those out. A profile picks one with `toolsets:` in `hermes_profiles`.
- Every profile also gets `proxy.enabled: false` (iron-proxy egress needs static API keys, which the OAuth-based `openai-codex` provider does not have), `compression.threshold: 0.5`, and the local headless browser. These live in `config/hermes/common.yml.j2`.
- `hermes_profiles`: the specialist profiles. Each entry has a `name` (the Hermes profile and CLI alias), a `role` (the folder under `config/software-factory/agents/` holding its `SOUL.md`), an optional `gateway: true` for profiles you message directly, an optional `toolsets` (`main` or `specialist`, default `specialist`), and an optional `model` (a key of `hermes_models`). By default only the main profile and `hoe` have gateways; the other specialists are reached through the factory workflow. To add a profile, add an entry and a matching `SOUL.md`; profile creation, settings, role prompts, gateway restarts, and verification all follow the list.

The target user is not a setting: it is the user running the commands, or `VPS_USER=<user>` when a different sudo account applies the playbook. Credentials never go in these files; configure them through Hermes setup on the VPS.

## First setup

### Root-only VPS: create an admin user first

If you can only log in as `root`, run this as root once:

```bash
git clone <this repository> && cd <repository folder>
./scripts/create-admin-user.sh <user>
```

It creates `<user>` with a password (used for `sudo`), adds it to the `sudo` group, and copies root's `~/.ssh/authorized_keys` to it. Keep the root session open, then from your own machine confirm `ssh <user>@<server>` works with your key and that `sudo whoami` prints `root`. Continue below as `<user>`, in a clone of this repository in that user's home.

### Configure your settings

Before installing, create `ansible/local-vars.yml` (gitignored) with your agents' Git identity and any commit trailers. Use a GitHub account for the agent (or your own) and its noreply address from github.com/settings/emails:

```bash
cp ansible/local-vars.example.yml ansible/local-vars.yml
nano ansible/local-vars.yml
```

```yaml
agent_git_name: 'my-agent-bot'
agent_git_email: '12345678+my-agent-bot@users.noreply.github.com'
agent_commit_trailers:
  - 'Co-Authored-By: Your Name <87654321+your-username@users.noreply.github.com>'
agent_forward_env: [GH_TOKEN]   # only if agents push to GitHub; see "GitHub access for agents"
```

Add any other overrides from the Settings section, such as `ssh_password_login: true`. You can change these later: run `make configure` for trailers and Hermes settings, and `make image-qa` for the Git identity.

### Install

Run these as the normal sudo user. `make install` disables root and password SSH login, so keep your current SSH session open and confirm a new key-based login works afterwards:

```bash
make install
```

If the playbook added the user to the Docker group, close the SSH session and reconnect so the new group membership takes effect. Then continue as `<user>`:

```bash
if [[ ! -x "$HOME/.local/bin/hermes" ]]; then make hermes-install; fi
~/.local/bin/hermes setup           # Full setup; sign in with OpenAI Codex (shared by all profiles)
make configure                      # 1st: create hoe/techlead/engineer/qa, apply managed settings
make provider-keys                  # OpenRouter key, asked once and set on every profile that uses it
~/.local/bin/hermes gateway setup   # Telegram for the main profile
~/.local/bin/hoe gateway setup      # Telegram for hoe
~/.local/bin/hermes gateway install
~/.local/bin/hoe gateway install
make configure                      # 2nd: re-apply settings the wizards changed, restart gateways
make image-qa
make verify
```

Only the main profile needs `hermes setup`. Named profiles without their own ChatGPT sign-in use the main profile's (`~/.hermes/auth.json`), OpenRouter profiles get their key from `make provider-keys`, and `make configure` sets everything else for them: model, tools, terminal, and role prompt. Run `<profile> setup` only to give a profile a different account or provider. Gateways are set up only for the profiles you message (the main profile and those with `gateway: true`).

Run `make image-qa` as the target user (or with `VPS_USER=<user>`) so the image runs with that user's UID/GID.

Complete the interactive model sign-in and messaging setup directly on the VPS. Do not put credentials in this repository or send them in chat.

The workflow setup commands are interactive. If you already restored valid profile state and gateway units, run `make configure` and `make verify`. Run Hermes installation, setup, and gateway commands while logged in as `<user>` so its profiles and services belong to the intended user. If a different sudo account applies the base playbook, use `VPS_USER=<user> make install`, then switch to `<user>` for the Hermes commands. Do not run `make install` as root.

On a fresh VPS without Hermes, `make hermes-install` pins the application source to the `hermes_commit` setting (Hermes v0.21.2 by default). It downloads the installer script from that immutable commit and refuses to run when Hermes is already installed. If a Hermes CLI is already present, skip the install command and run `make configure`.

## Commands

- `make install`: install OS prerequisites and apply the base playbook.
- `make hermes-install`: install the pinned Hermes source revision when no Hermes CLI is present.
- `make configure`: apply the workspace and managed Hermes configuration again.
- `make provider-keys`: set API keys (OpenRouter) on every profile whose model needs one. `scripts/set-provider-keys.sh --check` shows which are set without printing them.
- `make image-qa`: build the Playwright terminal image used by the specialist profiles, owned by the target user's UID/GID. If the image changed, it then removes containers still running the previous build (asking first when run interactively), because Hermes otherwise keeps reusing them.
- `make verify`: verify the host, workspace, Hermes settings, and required specialist Docker image.
- `make update`: fetch nothing automatically; run `git pull --ff-only` yourself, review the diff, then `make configure`.

## Target layout and access

The factory root is `/home/<user>/software-factory`. If only an older-layout directory `/home/<user>/projects/software-factory` exists, the playbook moves it to the new path and preserves its contents. If both paths exist, it stops so you can reconcile them without overwriting either one. Projects are kept under `projects/<project-name>/`; repositories and required docs are organized as described in its `AGENTS.md` and `WORKFLOW.md`.

The default Hermes profile uses the `local` terminal backend and runs as the configured Unix user. Specialist profiles use the `docker` terminal backend, start in `/workspace`, and receive only the read-write mount `/home/<user>/software-factory:/workspace`. Automatic CWD mounting is disabled, and only the variables named in `agent_forward_env` (none by default) are passed in, taken from the profile's own `.env`.

The container volume list scopes the specialist terminal environment. The gateway process itself runs as the configured Unix user. Each Hermes profile has separate configuration and session state.

## GitHub access for agents

The specialist containers cannot see the host's SSH keys or Git credentials. To let agents push branches and open pull requests, give them a GitHub token through the profile's `.env`. The terminal image includes the GitHub CLI (`gh`), and Git uses it to authenticate `https://github.com` with that token. `git@github.com:` remotes are rewritten to HTTPS so they use it too.

1. Use a separate GitHub account for the agents (the one in `agent_git_name`), and add it as a collaborator only on the repositories they should work on.
2. On that account, create a token at github.com/settings/tokens:
   - **Classic token** with the `repo` and `workflow` scopes. It reaches only the repositories the account was added to. This is the option that works for repositories owned by another personal account.
   - Or a **fine-grained token**, if the repositories belong to the agent account itself or to an organization: Contents, Pull requests, and Workflows set to read and write.
3. Add it to the `.env` of each profile that pushes or opens pull requests (usually `engineer` and `qa`), readable only by you:
   ```bash
   for p in engineer qa; do
     f=~/.hermes/profiles/$p/.env
     touch "$f" && chmod 600 "$f"
     read -rsp "GH_TOKEN for $p: " t && echo && printf 'GH_TOKEN=%s\n' "$t" >> "$f"
   done
   ```
   `read -s` keeps the token out of your shell history and screen.
4. Set `agent_forward_env: [GH_TOKEN]` in `ansible/local-vars.yml`, then run `make image-qa` (adds `gh`) and `make configure`.
5. Check: `qa chat`, then ask it to run `gh auth status`. It should report being logged in as the agent account. The token never needs to appear in chat, Telegram, or Kanban.

Profiles without `GH_TOKEN` in their `.env` get nothing, even though the name is forwarded for all specialists. Revoke the token on GitHub at any time to cut off access.

## Android builds

Set `android_sdk: true` in `ansible/local-vars.yml`, then run `make image-qa` and `make configure`. The terminal image then includes:

- Temurin JDK 17 and the Android SDK command-line tools, both pinned by version and SHA-256.
- The packages in `android_sdk_packages` (default `platform-tools`, `platforms;android-36`, `build-tools;36.0.0`), with `ANDROID_HOME` set. The SDK belongs to the container user, so Gradle can download other components a project needs; those last until the container is recreated, so add regularly needed ones to `android_sdk_packages`.

Enabling it accepts the Android SDK licence terms, and makes the image about 3-5 GB larger.

Gradle's cache lives on the host in `~/.cache/hermes-gradle`, mounted as `~/.gradle` in the specialist containers, so dependencies are downloaded once rather than per container. Its managed `gradle.properties` caps the Gradle JVM with `android_gradle_jvmargs` (default 2 GB heap), turns off long-lived Gradle and Kotlin daemons, and limits Gradle to 2 workers. An Android build still needs 2-4 GB of RAM, so on a small VPS avoid running several builds at once. Emulator and instrumented tests are not supported: they need KVM inside the container.

`make verify` checks the JDK, each configured package, and the Gradle cache when `android_sdk` is enabled.

## Security notes

- Docker writes its own iptables rules, so a port published with `docker run -p` or Compose `ports:` is reachable from the internet even though UFW denies incoming traffic. This setup publishes no ports. If you add services, bind them to `127.0.0.1` or put them behind a reverse proxy.
- Agents can read any token you forward with `agent_forward_env`, so scope it to the agent account and the repositories it needs.
- Specialist containers get only the factory mount. Do not add `~/.hermes`, `/var/run/docker.sock`, or the whole home directory to `docker_volumes`; `make verify` fails if the mount list changes.
- Membership in the `docker` group is equivalent to root on the host (see `docker_group_access`).

## Machine-specific dependencies

The Playwright image build file is included under `docker/playwright-qa/`. Run `make image-qa` before using specialist terminal calls; `make verify` checks for the image and that it can write to the factory. The upstream base image is pinned by digest; OS packages installed during the build are not, so rebuilds are not guaranteed to be byte-for-byte identical. When `git_commit_signing` is enabled, the playbook sets host Git signing preferences, but a GPG key must be restored or generated before signed commits can succeed. Docker packages follow the Ubuntu 24.04 repository and are not pinned to package snapshots. GitHub authentication and backup restoration are documented in `docs/next-steps.md`.

## Agent guidance

`config/software-factory/` contains the shared `AGENTS.md`, `WORKFLOW.md`, and role-specific `SOUL.md` files. Ansible installs shared guidance in the factory (rendering the factory path into `AGENTS.md`) and each role prompt into its Hermes profile. The role list in `AGENTS.md` is prose; update it if you change `hermes_profiles`. QA is named Diana.
