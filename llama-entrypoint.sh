#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# llama-entrypoint.sh
#
# Starts the bundled llama-server in the background, then hands off to the
# standard GitHub Actions runner entrypoint (/entrypoint.sh).
#
# Environment variables:
#   LLAMA_MODEL  – path to the GGUF model file (set in the Dockerfile)
#   LLAMA_HOME   – directory containing the llama-server binary (on PATH)
#   LLAMA_HOST   – bind address (default: 0.0.0.0)
#   LLAMA_PORT   – listen port   (default: 8080)
# ---------------------------------------------------------------------------

LLAMA_HOST="${LLAMA_HOST:-0.0.0.0}"
LLAMA_PORT="${LLAMA_PORT:-8080}"

: "${LLAMA_MODEL:?LLAMA_MODEL is required}"

echo "Starting llama-server: model=${LLAMA_MODEL} host=${LLAMA_HOST} port=${LLAMA_PORT}"

llama-server \
  --model  "${LLAMA_MODEL}" \
  --host   "${LLAMA_HOST}" \
  --port   "${LLAMA_PORT}" \
  &

LLAMA_PID=$!

# Fail fast: if llama-server exits immediately it likely failed to load the model.
sleep 1
if ! kill -0 "${LLAMA_PID}" 2>/dev/null; then
  echo "ERROR: llama-server (pid ${LLAMA_PID}) exited immediately." >&2
  exit 1
fi

echo "llama-server started (pid ${LLAMA_PID})."

# Propagate signals and ensure llama-server is stopped when the runner exits.
_cleanup() {
  echo "Stopping llama-server (pid ${LLAMA_PID})..."
  kill "${LLAMA_PID}" 2>/dev/null || true
  wait "${LLAMA_PID}" 2>/dev/null || true
}
trap _cleanup EXIT INT TERM

# Hand off to the Actions runner entrypoint, passing through any arguments.
# Do NOT exec here so the EXIT trap fires when the runner finishes and we can
# stop llama-server cleanly.
/entrypoint.sh "$@"
