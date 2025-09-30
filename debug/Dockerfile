# syntax=docker/dockerfile:1.4
FROM --platform=$BUILDPLATFORM ubuntu:22.04 AS base

ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    vim \
    curl \
    wget \
    git \
    bash \
    unzip \
    gnupg \
    ansible \
    build-essential \
    file \
    gcc \
    make \
    mercurial \
    pkg-config \
    rsync \
    xz-utils \
    zlib1g-dev \
    gcc \
    python3-dev \
    python3-pip \
    apt-transport-https \
    lsb-release \
    openssh-client \
    ca-certificates \
    software-properties-common \
    bison \
    uuid-runtime \
    shellcheck \
    zip \
    jq \
    procps \
    net-tools \
    gnuplot \
    bsdextrautils \
    gettext-base \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install Go
ARG GO_VERSION=1.24.7
RUN curl -LO https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz && \
    tar -C /usr/local -xzf go${GO_VERSION}.linux-${TARGETARCH}.tar.gz && \
    rm go${GO_VERSION}.linux-${TARGETARCH}.tar.gz
ENV PATH=$PATH:/usr/local/go/bin

ENV GOPATH /go
ENV PATH $GOPATH/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"

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

# Extra tools through go install
# These run using the golang image version of Go, not any defined by `gvm`
ARG KAIL_VERSION=v0.17.4
ARG GOTESTSUM_VERSION=v1.11.0
ARG PROTOC_GEN_GO_VERSION=v1.28.0
ARG GO_LICENSES_VERSION=v1.6.0
ARG JSONNET_VERSION=v0.18.0
ARG COSIGN_VERSION=v1.13.6
ARG TOOLBOX_VERSION=cdf9cf656d1402c5c8ca558ef7f7b7ef2ff9093b

# Disable CGO libs to avoid error with too old version in base image
ENV CGO_ENABLED=0
# Disable Go' toolchain operation, and stick to the version installed
ENV GOTOOLCHAIN=local

RUN go install rsc.io/goversion@v1.2.0

RUN go install github.com/boz/kail/cmd/kail@${KAIL_VERSION}
RUN go install gotest.tools/gotestsum@${GOTESTSUM_VERSION}
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@${PROTOC_GEN_GO_VERSION}
RUN go install github.com/google/go-licenses@${GO_LICENSES_VERSION}
RUN go install github.com/google/go-jsonnet/cmd/jsonnet@${JSONNET_VERSION}
RUN go install github.com/sigstore/cosign/cmd/cosign@${COSIGN_VERSION}
RUN go install knative.dev/toolbox/provenance-generator@${TOOLBOX_VERSION}
RUN go install knative.dev/toolbox/flaky-test-reporter@${TOOLBOX_VERSION}
RUN go install knative.dev/toolbox/pkg/clustermanager/perf-tests@${TOOLBOX_VERSION}
RUN go install knative.dev/toolbox/kntest/cmd/kntest@${TOOLBOX_VERSION}

# Final image
FROM base AS final
CMD ["/bin/bash"]
