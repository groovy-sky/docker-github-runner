# Dockerized GitHub Actions Self-hosted Runner

![](logo.svg)

This repository contains Docker images for a GitHub Actions self-hosted runner. It provides ready-to-use images including `ghcr.io/groovy-sky/gh-runner:latest` and the llama-enabled `ghcr.io/groovy-sky/llama-gh-runner:latest`.

## Build

```sh
docker build -t gh-runner:latest .
```

Build the llama-enabled variant:

```sh
docker build -f llama.Dockerfile -t llama-gh-runner:latest .
```

## Run

Github runner can be used as a repository or organization runner. The only difference is the GITHUB_URL and the required permissions for the GITHUB_PAT.

Full variable list with definition:
* GITHUB_URL - URL of the repository or organization to register the runner to. Examples: `https://github.com/OWNER/REPO`, `https://github.com/ORG`, `https://<enterprise-host>/OWNER/REPO`, or `https://<enterprise-host>/ORG` (for example `https://acme.ghe.com/OWNER/REPO`).
  - API endpoint resolution for `GITHUB_PAT`: `github.com` uses `https://api.github.com`; `*.ghe.com` tries `https://api.ghe.com` first, then `https://api.<enterprise-host>`, then `https://<enterprise-host>/api/v3`; other enterprise hosts use `https://<enterprise-host>/api/v3`.
* GITHUB_PAT - Personal Access Token with appropriate scopes to register/remove runners. For repository runners, the token needs `repo` scope. For organization runners, the token needs `admin:org` scope.
* RUNNER_NAME - Name of the runner to register. This can be any string and is used to identify the runner in GitHub.
* DEFAULT_RUNNER_GROUP - (Optional) Default GitHub self-hosted runner group to use when `RUNNER_GROUP` is unset or empty. Defaults to `Default`.
* RUNNER_GROUP - (Optional) Name of an existing GitHub self-hosted runner group. When set to a non-empty value, it overrides `DEFAULT_RUNNER_GROUP`.
* RUNNER_LABELS - (Optional) Comma-separated list of labels to assign to the runner. Use labels (and workflow `runs-on`) to target workloads; do not put labels in `RUNNER_GROUP`.
* RUNNER_WORKDIR - (Optional) Directory inside the container to use as the runner's working directory. Default is `_work`.
* RUNNER_TOKEN - (Optional) Short-lived registration token to use instead of GITHUB_PAT. If both GITHUB_PAT and RUNNER_TOKEN are provided, GITHUB_PAT is used to mint a fresh registration token.
* EPHEMERAL - (Optional) If set to "true", the runner is registered as ephemeral. Default is "true".
* DISABLE_AUTO_UPDATE - (Optional) If set to "true", disable automatic runner binary updates. Default is "true".

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
  -e DEFAULT_RUNNER_GROUP="Default" \
  -e RUNNER_LABELS="self-hosted,linux,x64,docker" \
  gh-runner:latest
```

If `RUNNER_GROUP` is unset or empty, the runner is registered in `DEFAULT_RUNNER_GROUP` (which defaults to `Default`).
If `RUNNER_GROUP` is set to a non-empty value, it must exactly match an existing GitHub self-hosted runner group at the scope implied by `GITHUB_URL`.
Use `RUNNER_LABELS` for workflow routing labels; `RUNNER_GROUP` accepts a single runner-group name, not a comma-separated label list.

## Llama-enabled image and MCP configuration

The llama-enabled image bundles `llama.cpp`'s `llama-server` and starts it locally on `http://0.0.0.0:8080/v1` by default via `/llama-entrypoint.sh`. This server is OpenAI-compatible model inference only; it is not an MCP client and does not directly load or invoke MCP servers.

For MCP-capable agents/clients running inside the container, the image ships a version-controlled remote MCP configuration at the path set by `MCP_CONFIG_PATH` (`/opt/mcp/mcp.json`). The file contains opt-in Streamable HTTP server definitions for:

* Microsoft Foundry - `https://mcp.ai.azure.com`
* Azure Resource Manager - `https://mcp.management.azure.com`
* GitHub - `https://api.githubcopilot.com/mcp`
* Microsoft Learn - `https://learn.microsoft.com/api/mcp`

The configuration intentionally does not include credentials or tokens. Authentication and any client-specific MCP enablement must be supplied by the MCP-capable agent/client you run in the container.

## Detailed guideline

For more detailed guideline on how to create and use GitHub Actions self-hosted runners you can check [the official documentation](https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners) or this [comprehensive tutorial](https://github.com/groovy-sky/azure/blob/master/github-runner-00/README.md#introduction).
