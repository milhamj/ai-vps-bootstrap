# Pinned by digest (multi-arch index, tag python3.11-nodejs20 as of 2026-03-25) for reproducible builds.
# To update: look up the tag's current digest on Docker Hub, replace it here, rebuild, and run make verify.
ARG BASE_IMAGE=nikolaik/python-nodejs:python3.11-nodejs20@sha256:8f958bdc1b4a422bfafd97cab4f69836401f616ae985d4b57a53d254f5bcb038
FROM ${BASE_IMAGE}

# Run as the host user's UID/GID so the container can read and write the mounted factory.
ARG HERMES_UID=1000
ARG HERMES_GID=1000

USER root

ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
ENV HOME=/home/hermes
ENV NPM_CONFIG_CACHE=/home/hermes/.npm

RUN mkdir -p /home/hermes/.npm \
    && npx -y playwright@1.63.0 install --with-deps chromium firefox webkit \
    && chmod -R a+rX /ms-playwright \
    && chown -R ${HERMES_UID}:${HERMES_GID} /home/hermes \
    && chmod 0755 /home/hermes \
    && chmod -R u+rwX /home/hermes/.npm \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI for pull requests. Git uses it as the credential helper for https://github.com, so a
# GH_TOKEN (or GITHUB_TOKEN) forwarded into the container authenticates both gh and git push.
# SSH-style github.com remotes are rewritten to HTTPS so they use the same token.
RUN install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod a+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/* \
    && git config --system --add credential.https://github.com.helper '' \
    && git config --system --add credential.https://github.com.helper '!/usr/bin/gh auth git-credential' \
    && git config --system url.https://github.com/.insteadOf git@github.com:

# Optional Android toolchain (android_sdk: true): Temurin JDK 17 and the Android SDK command-line
# tools, both pinned by version and SHA-256, plus the packages in android_sdk_packages. Building
# with ANDROID_SDK=true accepts the Android SDK licence terms. The SDK is owned by the container
# user so Gradle can add components it needs; those last until the container is recreated.
# These variables are harmless when the toolchain is not installed.
ENV ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    PATH=/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:$PATH
ARG ANDROID_SDK=false
ARG ANDROID_SDK_PACKAGES="platform-tools platforms;android-36 build-tools;36.0.0"
ARG JDK_URL=https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.20.1%2B1/OpenJDK17U-jdk_x64_linux_hotspot_17.0.20.1_1.tar.gz
ARG JDK_SHA256=3808d1d15e3ec6bd5b84057fb5d84c33d8a1536a258146bcea2e603fc726e08e
ARG ANDROID_TOOLS_URL=https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip
ARG ANDROID_TOOLS_SHA256=7ec965280a073311c339e571cd5de778b9975026cfcbe79f2b1cdcb1e15317ee
RUN if [ "$ANDROID_SDK" = "true" ]; then \
      set -e; tmp=$(mktemp -d); \
      curl -fsSL "$JDK_URL" -o "$tmp/jdk.tar.gz"; \
      echo "$JDK_SHA256  $tmp/jdk.tar.gz" | sha256sum -c -; \
      mkdir -p /opt/jdk-17 && tar -xzf "$tmp/jdk.tar.gz" -C /opt/jdk-17 --strip-components=1; \
      for tool in /opt/jdk-17/bin/*; do ln -sf "$tool" /usr/local/bin/; done; \
      curl -fsSL "$ANDROID_TOOLS_URL" -o "$tmp/tools.zip"; \
      echo "$ANDROID_TOOLS_SHA256  $tmp/tools.zip" | sha256sum -c -; \
      python3 -m zipfile -e "$tmp/tools.zip" "$tmp"; \
      mkdir -p "$ANDROID_HOME/cmdline-tools" && mv "$tmp/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"; \
      chmod +x "$ANDROID_HOME"/cmdline-tools/latest/bin/*; \
      yes | sdkmanager --licenses >/dev/null; \
      sdkmanager --install $ANDROID_SDK_PACKAGES; \
      chown -R ${HERMES_UID}:${HERMES_GID} "$ANDROID_HOME"; \
      rm -rf "$tmp"; \
    fi

# Git identity for agent commits (agent_git_name / agent_git_email). Declared after the browser
# layer so changing it does not re-download browsers. Left unset when empty.
ARG AGENT_GIT_NAME=
ARG AGENT_GIT_EMAIL=
RUN if [ -n "$AGENT_GIT_NAME" ]; then git config --system user.name "$AGENT_GIT_NAME"; fi \
    && if [ -n "$AGENT_GIT_EMAIL" ]; then git config --system user.email "$AGENT_GIT_EMAIL"; fi

USER ${HERMES_UID}:${HERMES_GID}
WORKDIR /workspace
