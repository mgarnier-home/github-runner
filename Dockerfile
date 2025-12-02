# Define base images as build arguments (allow customization in CI/CD pipelines)
ARG GO_BUILD_VERSION="golang:bookworm"
ARG DEBIAN_IMAGE="debian:bookworm-slim"

# ---- Build Stage ----
FROM $GO_BUILD_VERSION AS builder

# Set working directory inside the container
WORKDIR /go

# Define ASDF version (must be set when building a derived image)
ARG ASDF_VERSION="v0.17.0"

# Build ASDF Go binary (ASDF is a Go-based CLI tool)
RUN go install  github.com/asdf-vm/asdf/cmd/asdf@$ASDF_VERSION

# ---- Final Stage (Minimal Runtime Image) ----
FROM $DEBIAN_IMAGE
LABEL authors="Operis"

# Install packages, docker, gh cli and az cli
COPY ./scripts/install.sh /install.sh
RUN /bin/bash /install.sh && rm /install.sh && which git

# Set ASDF-related environment variables (ensures proper path resolution)
ENV ASDF_DATA_DIR="/asdf"
ENV PATH="${PATH}:/asdf/shims:/asdf/bin"

# Copy the ASDF binary from the builder stage
COPY --from=builder /go/bin/asdf /usr/local/bin/asdf

# Install asdf plugins
RUN \
  asdf plugin add nodejs && \
  asdf plugin add deno && \
  asdf plugin add java && \
  asdf plugin add maven && \
  asdf plugin add php && \
  asdf plugin add terraform https://github.com/asdf-community/asdf-hashicorp.git && \
  asdf plugin add yq


RUN \
  asdf install yq 4.47.2

ENV AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache
RUN \
  mkdir -p /opt/hostedtoolcache && \
  chown -R runner:runner /opt/hostedtoolcache && \
  chown -R runner:runner /asdf

# ---- Runner configuration ----
ARG GH_RUNNER_VERSION="2.329.0"

# Set to linux/arm64 to build for arm
ARG TARGETPLATFORM

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /actions-runner
COPY ./scripts/install_actions.sh /actions-runner

RUN chmod +x /actions-runner/install_actions.sh \
  && /actions-runner/install_actions.sh ${GH_RUNNER_VERSION} ${TARGETPLATFORM} \
  && rm /actions-runner/install_actions.sh \
  && chown runner /_work /actions-runner /opt/hostedtoolcache

COPY ./scripts/token.sh ./scripts/entrypoint.sh ./scripts/app_token.sh /
RUN chmod +x /token.sh /entrypoint.sh /app_token.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["./bin/Runner.Listener", "run", "--startuptype", "service"]
