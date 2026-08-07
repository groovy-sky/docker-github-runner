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
ARG TARGETARCH
ARG MODEL_FILE="Huihui-gemma-4-E2B-it-qat-q4_0-unquantized-abliterated-Q4_K.gguf"
ARG NODE_VERSION="22.17.1"
ARG AZURE_MCP_NPM_VERSION="3.0.0-beta.32"
ARG FABRIC_MCP_NPM_VERSION="1.2.0"

ENV RUNNER_HOME=/opt/actions-runner
ENV LLAMA_HOME=/opt/llama.cpp
ENV LLAMA_MODEL_DIR=/models
ENV LLAMA_MODEL=/models/${MODEL_FILE}
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
 && case "${TARGETARCH:-amd64}" in \
      amd64) NODE_ARCH="x64" ;; \
      arm64) NODE_ARCH="arm64" ;; \
      *) echo "Unsupported TARGETARCH for Node.js: ${TARGETARCH:-unknown}"; exit 1 ;; \
    esac \
 && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" \
    -o /tmp/node.tar.xz \
 && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 --no-same-owner \
 && rm -f /tmp/node.tar.xz \
 && node --version \
 && npm --version \
 && npm install --global --no-audit --no-fund \
      "@azure/mcp@${AZURE_MCP_NPM_VERSION}" \
      "@microsoft/fabric-mcp@${FABRIC_MCP_NPM_VERSION}" \
 && npm cache clean --force \
 && rm -rf /var/lib/apt/lists/*

RUN useradd -m -d /home/runner -s /bin/bash -u 1001 runner

COPY --from=runner-downloader /opt/actions-runner ${RUNNER_HOME}
COPY --from=llama-server /app ${LLAMA_HOME}
COPY --from=model-downloader /models ${LLAMA_MODEL_DIR}

COPY entrypoint.sh /entrypoint.sh
COPY llama-entrypoint.sh /llama-entrypoint.sh
COPY configure.sh /usr/local/bin/configure-runner
RUN chmod +x /entrypoint.sh /llama-entrypoint.sh /usr/local/bin/configure-runner "${LLAMA_HOME}/llama-server" \
 && azmcp --version \
 && fabmcp --version \
 && chown -R runner:runner "${RUNNER_HOME}" "${LLAMA_HOME}" "${LLAMA_MODEL_DIR}" /home/runner

WORKDIR ${RUNNER_HOME}
USER runner

# llama-entrypoint.sh starts the bundled llama-server (on LLAMA_HOST:LLAMA_PORT,
# default 0.0.0.0:8080) and then delegates to /entrypoint.sh for the runner.
# Override host/port with LLAMA_HOST / LLAMA_PORT environment variables.
# Bundled Microsoft MCP servers can be started with:
# azmcp server start
# fabmcp server start --mode all
EXPOSE 8080
ENTRYPOINT ["/llama-entrypoint.sh"]
