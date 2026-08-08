# Dockerized GitHub Actions Self-hosted Runner

![](logo.svg)

This repostiory contains a docker image for a GitHub Actions self-hosted runner. It also provides a ready-to-use image - `ghcr.io/groovy-sky/gh-runner:latest`

## Build

```sh
docker build -t gh-runner:latest .
```

## Run

Github runner can be used as a repository or organization runner. The only difference is the GITHUB_URL and the required permissions for the GITHUB_PAT.

Full variable list with definition:
* GITHUB_URL - URL of the repository or organization to register the runner to. Examples: `https://github.com/OWNER/REPO` or `https://github.com/ORG`.
* GITHUB_PAT - Personal Access Token with appropriate scopes to register/remove runners. For repository runners, the token needs `repo` scope. For organization runners, the token needs `admin:org` scope.
* RUNNER_NAME - Name of the runner to register. This can be any string and is used to identify the runner in GitHub.
* RUNNER_GROUP - (Optional) Name of an existing GitHub self-hosted runner group. Omit this in most cases so the runner is registered in GitHub's default runner group.
* RUNNER_LABELS - (Optional) Comma-separated list of labels to assign to the runner. Use labels (and workflow `runs-on`) to target workloads.
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
  -e RUNNER_GROUP="Default" \
  -e RUNNER_LABELS="self-hosted,linux,x64,docker" \
  gh-runner:latest
```

`RUNNER_GROUP` must exactly match an existing GitHub self-hosted runner group at the scope implied by `GITHUB_URL`.
If you are not intentionally assigning a non-default group, leave `RUNNER_GROUP` unset.

## Detailed guidiline

For more detailed guideline on how to create and use GitHub Actions self-hosted runners you can check [the official documentation](https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners) or this [comprehensive tutorial](https://github.com/groovy-sky/azure/blob/master/github-runner-00/README.md#introduction).
