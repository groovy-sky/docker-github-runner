# Dockerized GitHub Actions Self-hosted Runner

![](logo.svg)

Docker image for a GitHub Actions self-hosted runner.

## Build

```sh
docker build -t gh-runner:latest .
```

Multi-arch build (local tags):

```sh
# amd64
docker build --platform linux/amd64 -t gh-runner:amd64 .

# arm64
docker build --platform linux/arm64 -t gh-runner:arm64 .
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

## Verify and Remove

```sh
docker logs -f gh-runner-01

docker stop gh-runner-01
docker rm gh-runner-01
```

## Docker Hub Publish Workflow

Workflow file:

- .github/workflows/gh-runner-publish.yml

What it does:

- Builds and pushes linux/amd64 and linux/arm64
- Pushes tags for latest (default branch), git tags, and short SHA

Required GitHub repository secrets:

- DOCKERHUB_USERNAME
- DOCKERHUB_TOKEN

## Security

- Treat runner hosts as trusted infrastructure
- Prefer ephemeral runners
- Avoid storing long-lived secrets on runner hosts
