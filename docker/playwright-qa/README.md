# Playwright QA terminal image

The specialist Hermes profiles use the image named by `hermes_docker_image` (default `hermes-qa-playwright:1.63.0`). Build it from the VPS project root after Docker is installed and the target user can access the Docker daemon:

```bash
make image-qa
```

This runs `scripts/build-image.sh`, which builds `Dockerfile` with `HERMES_UID`/`HERMES_GID` set to the target user's IDs (the user running the command, or `VPS_USER`), so files the agents create in `/workspace` belong to that user and the container can write to the factory directory.

The image is intended for `linux/amd64` and uses `/workspace` as its working directory. The Hermes profile config mounts only `/home/<user>/software-factory` there. `make verify` also starts a disposable container to confirm that this image user can read and write the mounted factory; if it fails, rebuild with `make image-qa` as the target user.

The base image `nikolaik/python-nodejs:python3.11-nodejs20` is pinned by digest in the `Dockerfile`, and the Playwright package version is pinned. `--with-deps` still installs OS packages from the repositories available at build time, so rebuilds reproduce the intended environment but not necessarily the same image digest. Snapshot the OS package sources if byte-for-byte rebuilds are required. To move to a newer base image, replace the digest in the `Dockerfile`, run `make image-qa`, and run `make verify`.
