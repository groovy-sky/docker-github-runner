# Dockerized GitHub Actions Self-hosted Runner

![](logo.svg)

Docker image for a GitHub Actions self-hosted runner.

## Prebuilt Image

Already available on GitHub Container Registry:

- Image: `ghcr.io/groovy-sky/gh-runner:latest`

## Build

```sh
docker build -t gh-runner:latest .
```

## Run

Repository runner:

```sh
docker run -d --name gh-runner-01 \
  --restart unless-stopped \
  -e GITHUB_URL="https://github.com/OWNER/REPO" \
  -e GITHUB_PAT="GITHUB_PAT_WITH_REPO_RUNNER_SCOPE" \
  -e RUNNER_NAME="runner-01" \
  -e RUNNER_LABELS="self-hosted,linux,x64,docker" \
  -e RUNNER_WORKDIR="_work" \
  gh-runner:latest
```

Organization runner:

```sh
docker run -d --name gh-org-runner-01 \
  --restart unless-stopped \
  -e GITHUB_URL="https://github.com/ORG" \
  -e GITHUB_PAT="GITHUB_PAT_WITH_ADMIN_ORG_SCOPE" \
  -e RUNNER_NAME="org-runner-01" \
  -e RUNNER_GROUP="default" \
  -e RUNNER_LABELS="self-hosted,linux,x64,docker" \
  gh-runner:latest
```

## Required Runtime Variables

- GITHUB_URL: https://github.com/OWNER/REPO or https://github.com/ORG
- One of:
  - RUNNER_TOKEN (short-lived registration token)
  - GITHUB_PAT (used to request short-lived register/remove tokens)

Optional:

- RUNNER_NAME (default: hostname)
- RUNNER_LABELS (comma-separated)
- RUNNER_GROUP (organization runners)
- RUNNER_WORKDIR (default: _work)
- EPHEMERAL (default: true)
- DISABLE_AUTO_UPDATE (default: true)

Examples:

```sh
# persistent runner
-e EPHEMERAL="false"

# enable runner auto-update
-e DISABLE_AUTO_UPDATE="false"
```