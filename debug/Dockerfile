# syntax=docker/dockerfile:1.4
FROM --platform=$BUILDPLATFORM ubuntu:22.04 AS base

ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    bash \
    unzip \
    gnupg \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install Go
ARG GO_VERSION=1.25.1
RUN curl -LO https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz && \
    tar -C /usr/local -xzf go${GO_VERSION}.linux-${TARGETARCH}.tar.gz && \
    rm go${GO_VERSION}.linux-${TARGETARCH}.tar.gz
ENV PATH=$PATH:/usr/local/go/bin

# Install ko
RUN curl -LO https://github.com/ko-build/ko/releases/latest/download/ko_Linux_${TARGETARCH}.tar.gz && \
    tar -xzf ko_Linux_${TARGETARCH}.tar.gz -C /usr/local/bin && \
    rm ko_Linux_${TARGETARCH}.tar.gz

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${TARGETARCH}/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# Install Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install gcloud CLI
RUN if [ "$TARGETARCH" != "ppc64le" ] && [ "$TARGETARCH" != "s390x" ]; then \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" \
    > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
    apt-get update && apt-get install -y google-cloud-sdk \
    else echo "Skipping gcloud CLI for unsupported arch: $TARGETARCH"; \
    fi

# Install yq
RUN curl -L https://github.com/mikefarah/yq/releases/download/v4.25.3/yq_linux_$TARGETARCH -o /usr/bin/yq && \
    chmod +x /usr/bin/yq

# Final image
FROM base AS final
CMD ["/bin/bash"]
