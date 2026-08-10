#!/usr/bin/env bash
set -euo pipefail

image="${1:?Usage: $0 IMAGE}"

tools="$(docker run --rm --entrypoint /usr/local/bin/mcp-agent "${image}" \
  --server microsoft-learn --list-tools)"

jq -e '
  .server == "microsoft-learn"
  and (.tools | type == "array" and length > 0)
  and any(.[]; .name == "microsoft_docs_search")
' <<< "${tools}" >/dev/null

echo "Microsoft Learn MCP smoke test passed."
