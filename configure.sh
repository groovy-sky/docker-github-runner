#!/usr/bin/env bash
set -euo pipefail

cd /opt/actions-runner

normalize_github_url() {
  local normalized
  normalized="$1"
  if [[ "${normalized}" == http://* ]]; then
    echo "Unsupported GITHUB_URL format: ${normalized}" >&2
    echo "Use github.com/ORG, github.com/OWNER/REPO, <enterprise-host>/ORG, or <enterprise-host>/OWNER/REPO. https://... is accepted, but http://... is not." >&2
    return 1
  fi
  normalized="${normalized%%[\?#]*}"
  normalized="${normalized%/}"
  normalized="${normalized#https://}"
  printf '%s\n' "${normalized}"
}

fetch_registration_token() {
  local trimmed endpoint response code body token
  local host owner repo api_base
  local -a candidates=() api_bases=()

  trimmed="$(normalize_github_url "${GITHUB_URL}")" || return 1
  if [[ "${trimmed}" =~ ^([^/]+)/([^/]+)/([^/]+)$ ]]; then
    host="${BASH_REMATCH[1]}"
    owner="${BASH_REMATCH[2]}"
    repo="${BASH_REMATCH[3]}"
    candidates+=("repos/${owner}/${repo}")
  elif [[ "${trimmed}" =~ ^([^/]+)/([^/]+)$ ]]; then
    host="${BASH_REMATCH[1]}"
    owner="${BASH_REMATCH[2]}"
    candidates+=("orgs/${owner}")
  else
    echo "Unsupported GITHUB_URL format: ${GITHUB_URL}" >&2
    echo "Expected github.com/ORG, github.com/OWNER/REPO, <enterprise-host>/ORG, or <enterprise-host>/OWNER/REPO (with or without an https:// prefix)" >&2
    return 1
  fi

  if [[ -n "${GITHUB_API_URL:-}" ]]; then
    api_bases=("${GITHUB_API_URL%/}")
  elif [[ "${host}" == "github.com" ]]; then
    api_bases=("https://api.github.com")
  else
    api_bases=("https://${host}/api/v3")
  fi

  for api_base in "${api_bases[@]}"; do
    for candidate in "${candidates[@]}"; do
      endpoint="${api_base}/${candidate}/actions/runners/registration-token"
      response="$(curl -sS \
      -X POST \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -H "Authorization: Bearer ${GITHUB_PAT}" \
      -w $'\n%{http_code}' \
      "${endpoint}")"

      code="${response##*$'\n'}"
      body="${response%$'\n'*}"

      if [[ "${code}" == "404" ]]; then
        continue
      fi

      if [[ "${code}" != "200" && "${code}" != "201" ]]; then
        echo "GitHub API call failed (${code}) at ${endpoint}" >&2
        [[ -n "${body}" ]] && echo "${body}" >&2
        return 1
      fi

      token="$(jq -r '.token // empty' <<< "${body}")"
      if [[ -n "${token}" ]]; then
        printf '%s\n' "${token}"
        return 0
      fi
    done
  done

  if [[ "${#candidates[@]}" == "1" && "${candidates[0]}" == orgs/* ]]; then
    echo "Failed to fetch registration token from GitHub API for organization '${owner}'." >&2
    echo "If this is a personal account, use a repository URL instead: github.com/OWNER/REPO" >&2
    return 1
  fi

  echo "Failed to fetch registration token from GitHub API." >&2
  return 1
}

# Required runtime env:
#   GITHUB_URL   -> github.com/<org-or-user>/<repo>, github.com/<org>,
#                   <enterprise-host>/<org-or-user>/<repo>, or <enterprise-host>/<org>
#   RUNNER_TOKEN -> registration token
#
# Optional:
#   GITHUB_PAT (used to dynamically mint registration token)
#   GITHUB_API_URL (optional API base override, e.g. https://api.github.com or https://<enterprise-host>/api/v3)
#   RUNNER_NAME (default: hostname)
#   DEFAULT_RUNNER_GROUP (default: Default)
#   RUNNER_LABELS (comma-separated)
#   RUNNER_GROUP (optional; overrides DEFAULT_RUNNER_GROUP when non-empty)
#   RUNNER_WORKDIR (default: _work)
#   EPHEMERAL (default: true)
#   DISABLE_AUTO_UPDATE (default: true)

print_runner_group_diagnostics() {
  local effective_runner_group scope_desc normalized_github_url
  effective_runner_group="${RUNNER_GROUP:-${DEFAULT_RUNNER_GROUP}}"
  normalized_github_url="$(normalize_github_url "${GITHUB_URL}")" || return 1

  if [[ "${normalized_github_url}" =~ ^[^/]+/([^/]+)/([^/]+)$ ]]; then
    scope_desc="repository '${BASH_REMATCH[1]}/${BASH_REMATCH[2]}'"
  elif [[ "${normalized_github_url}" =~ ^[^/]+/([^/]+)$ ]]; then
    scope_desc="organization '${BASH_REMATCH[1]}'"
  else
    scope_desc="the scope implied by GITHUB_URL"
  fi

  if [[ -n "${RUNNER_GROUP:-}" ]]; then
    echo "RUNNER_GROUP is set to '${RUNNER_GROUP}'."
  else
    echo "RUNNER_GROUP is not set; defaulting to '${DEFAULT_RUNNER_GROUP}'."
  fi
  echo "Runner will register in GitHub self-hosted runner group '${effective_runner_group}'."
  echo "The runner group must exactly match an existing GitHub self-hosted runner group visible to ${scope_desc} (${normalized_github_url})."
  echo "RUNNER_GROUP selects a GitHub runner group; it is not a workflow label list."
  echo "Use RUNNER_LABELS (and workflow runs-on labels) for workload targeting."
  if [[ -n "${RUNNER_GROUP:-}" && "${RUNNER_GROUP}" == *,* ]]; then
    echo "RUNNER_GROUP contains a comma. If you intended labels, move this value to RUNNER_LABELS." >&2
  fi
}

: "${GITHUB_URL:?GITHUB_URL is required}"

if [[ -z "${RUNNER_TOKEN:-}" && -z "${GITHUB_PAT:-}" ]]; then
  echo "Either RUNNER_TOKEN or GITHUB_PAT must be provided." >&2
  exit 1
fi

RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"
RUNNER_WORKDIR="${RUNNER_WORKDIR:-_work}"
DEFAULT_RUNNER_GROUP="${DEFAULT_RUNNER_GROUP:-Default}"
EPHEMERAL="${EPHEMERAL:-true}"
DISABLE_AUTO_UPDATE="${DISABLE_AUTO_UPDATE:-true}"
EFFECTIVE_RUNNER_GROUP="${RUNNER_GROUP:-${DEFAULT_RUNNER_GROUP}}"
NORMALIZED_GITHUB_URL="$(normalize_github_url "${GITHUB_URL}")"
CONFIG_GITHUB_URL="https://${NORMALIZED_GITHUB_URL}"

if [[ -n "${GITHUB_PAT:-}" ]]; then
  echo "Fetching short-lived registration token using GITHUB_PAT..."
  RUNNER_TOKEN="$(fetch_registration_token)"
elif [[ "${RUNNER_TOKEN:-}" == github_pat_* ]]; then
  echo "RUNNER_TOKEN appears to be a PAT, but this field requires a runner registration token." >&2
  echo "Set GITHUB_PAT instead, or provide a short-lived registration token in RUNNER_TOKEN." >&2
  exit 1
fi

CONFIG_ARGS=(
  --url "${CONFIG_GITHUB_URL}"
  --token "${RUNNER_TOKEN}"
  --name "${RUNNER_NAME}"
  --work "${RUNNER_WORKDIR}"
  --unattended
  --replace
)

if [[ -n "${RUNNER_LABELS:-}" ]]; then
  CONFIG_ARGS+=(--labels "${RUNNER_LABELS}")
fi

CONFIG_ARGS+=(--runnergroup "${EFFECTIVE_RUNNER_GROUP}")

if [[ "${EPHEMERAL}" == "true" ]]; then
  CONFIG_ARGS+=(--ephemeral)
fi

if [[ "${DISABLE_AUTO_UPDATE}" == "true" ]]; then
  CONFIG_ARGS+=(--disableupdate)
fi

print_runner_group_diagnostics

echo "Configuring runner ${RUNNER_NAME}..."
./config.sh "${CONFIG_ARGS[@]}"
