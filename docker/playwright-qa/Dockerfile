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

# Git identity for agent commits (agent_git_name / agent_git_email). Declared after the browser
# layer so changing it does not re-download browsers. Left unset when empty.
ARG AGENT_GIT_NAME=
ARG AGENT_GIT_EMAIL=
RUN if [ -n "$AGENT_GIT_NAME" ]; then git config --system user.name "$AGENT_GIT_NAME"; fi \
    && if [ -n "$AGENT_GIT_EMAIL" ]; then git config --system user.email "$AGENT_GIT_EMAIL"; fi

USER ${HERMES_UID}:${HERMES_GID}
WORKDIR /workspace
