# syntax=docker/dockerfile:1.7

##
## Stage 1: runner downloader
##
FROM --platform=$TARGETPLATFORM docker.io/ubuntu:24.04 AS runner-downloader

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      jq \
      tar \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/runner-download

RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
      amd64) RUNNER_ARCH="x64" ;; \
      arm64) RUNNER_ARCH="arm64" ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH:-unknown}"; exit 1 ;; \
    esac; \
    TAG_NAME="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name')"; \
    VERSION="${TAG_NAME#v}"; \
    FILE="actions-runner-linux-${RUNNER_ARCH}-${VERSION}.tar.gz"; \
    curl -fsSL -o runner.tgz "https://github.com/actions/runner/releases/download/${TAG_NAME}/${FILE}"; \
    mkdir -p /opt/actions-runner; \
    tar -xzf runner.tgz -C /opt/actions-runner; \
    rm -f runner.tgz; \
    test -x /opt/actions-runner/config.sh

##
## Stage 2: llama.cpp server binaries
##
FROM --platform=$TARGETPLATFORM ghcr.io/ggml-org/llama.cpp:server AS llama-server

##
## Stage 3: model downloader
##
FROM --platform=$TARGETPLATFORM docker.io/ubuntu:24.04 AS model-downloader

ARG DEBIAN_FRONTEND=noninteractive
ARG MODEL_URL="https://huggingface.co/huihui-ai/Huihui-gemma-4-E2B-it-qat-q4_0-unquantized-abliterated-GGUF/resolve/main/Huihui-gemma-4-E2B-it-qat-q4_0-unquantized-abliterated-Q4_K.gguf"
ARG MODEL_FILE="Huihui-gemma-4-E2B-it-qat-q4_0-unquantized-abliterated-Q4_K.gguf"

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    mkdir -p /models; \
    curl --fail --location --retry 5 --retry-all-errors \
      --output "/models/${MODEL_FILE}" "${MODEL_URL}"; \
    test -s "/models/${MODEL_FILE}"

##
## Stage 4: GitHub Actions runner with llama.cpp and the bundled GGUF model
##
FROM --platform=$TARGETPLATFORM docker.io/ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG MODEL_FILE="Huihui-gemma-4-E2B-it-qat-q4_0-unquantized-abliterated-Q4_K.gguf"

ENV RUNNER_HOME=/opt/actions-runner
ENV LLAMA_HOME=/opt/llama.cpp
ENV LLAMA_MODEL_DIR=/models
ENV LLAMA_MODEL=/models/${MODEL_FILE}
ENV MCP_CONFIG_PATH=/opt/mcp/mcp.json
ENV PATH="${RUNNER_HOME}:${LLAMA_HOME}:${PATH}"

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      iproute2 \
      jq \
      libcurl4 \
      libgomp1 \
      libicu74 \
      libkrb5-3 \
      liblttng-ust1 \
      libssl3 \
      lsb-release \
      tar \
      unzip \
      xz-utils \
      zlib1g \
 && rm -rf /var/lib/apt/lists/*

RUN useradd -m -d /home/runner -s /bin/bash -u 1001 runner

COPY --from=runner-downloader /opt/actions-runner ${RUNNER_HOME}
COPY --from=llama-server /app ${LLAMA_HOME}
COPY --from=model-downloader /models ${LLAMA_MODEL_DIR}

COPY entrypoint.sh /entrypoint.sh
COPY llama-entrypoint.sh /llama-entrypoint.sh
COPY configure.sh /usr/local/bin/configure-runner
COPY mcp/mcp.json ${MCP_CONFIG_PATH}
# Register llama.cpp shared libraries (e.g. libllama-server-impl.so) with the
# dynamic linker so that llama-server can find them at runtime.
RUN echo "/opt/llama.cpp" > /etc/ld.so.conf.d/llama-cpp.conf \
 && ldconfig \
 && chmod 644 "${MCP_CONFIG_PATH}" \
 && chmod +x /entrypoint.sh /llama-entrypoint.sh /usr/local/bin/configure-runner "${LLAMA_HOME}/llama-server" \
 && chown -R runner:runner "${RUNNER_HOME}" "${LLAMA_HOME}" "${LLAMA_MODEL_DIR}" /home/runner /opt/mcp

WORKDIR ${RUNNER_HOME}
USER runner

# llama-entrypoint.sh starts the bundled llama-server (on LLAMA_HOST:LLAMA_PORT,
# default 0.0.0.0:8080) as a local OpenAI-compatible inference server and then
# delegates to /entrypoint.sh for the runner. MCP-capable agents/clients can
# optionally load remote MCP server definitions from ${MCP_CONFIG_PATH}; llama.cpp
# does not connect to MCP servers directly. Override host/port with LLAMA_HOST /
# LLAMA_PORT environment variables.
EXPOSE 8080
ENTRYPOINT ["/llama-entrypoint.sh"]
