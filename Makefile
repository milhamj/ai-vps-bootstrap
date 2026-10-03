SHELL := /bin/bash
.DEFAULT_GOAL := help
.PHONY: help install hermes-install configure verify image-qa update
help:
	@printf 'Targets: install, hermes-install, configure, verify, image-qa, update\n'
install:
	./bootstrap.sh
hermes-install:
	./scripts/install-hermes.sh
configure:
	./scripts/configure.sh
verify:
	./scripts/verify.sh
image-qa:
	user=$${VPS_USER:-$$(id -un)} && \
	image=$$(python3 scripts/effective_vars.py hermes_docker_image) && \
	docker build --platform linux/amd64 -f docker/playwright-qa/Dockerfile \
	  --build-arg "HERMES_UID=$$(id -u "$$user")" --build-arg "HERMES_GID=$$(id -g "$$user")" \
	  -t "$$image" docker/playwright-qa
update:
	@printf 'Run git pull --ff-only, review the diff, then make configure.\n'
