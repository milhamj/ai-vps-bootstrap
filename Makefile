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
	./scripts/build-image.sh
update:
	@printf 'Run git pull --ff-only, review the diff, then make configure.\n'
