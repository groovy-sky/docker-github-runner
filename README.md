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
* GITHUB_URL - URL of the repository or organization to register the runner to. Examples:
* GITHUB_PAT - Personal Access Token with appropriate scopes to register/remove runners. For repository runners, the token needs `repo` scope. For organization runners, the token needs `admin:org` scope.
* RUNNER_NAME - Name of the runner to register. This can be any string and is used to identify the runner in GitHub.
* RUNNER_GROUP - (Optional) Name of the runner group to register the runner to.
* RUNNER_LABELS - (Optional) Comma-separated list of labels to assign to the runner. This can be used to target specific runners in your workflow files.
* RUNNER_WORKDIR - (Optional) Directory inside the container to use as the runner's working directory. Default is `_work`.
* RUNNER_TOKEN - (Optional) Token to use for authentication instead of GITHUB_PAT. This can be used to avoid storing a PAT in the container environment. If both GITHUB_PAT and RUNNER_TOKEN are provided, RUNNER_TOKEN will be used.
* RUNNER_EPHEMERAL - (Optional) If set to "true", the runner will be removed from GitHub after it finishes executing a job. Default is "false".

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

## Detailed guidiline

For more detailed guideline on how to create and use GitHub Actions self-hosted runners you can check [the official documentation](https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners) or this [comprehensive tutorial](https://github.com/groovy-sky/azure/blob/master/github-runner-00/README.md#introduction).