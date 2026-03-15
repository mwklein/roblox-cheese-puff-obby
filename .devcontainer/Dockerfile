# Force x86_64: rojo only ships Linux x86_64 binaries, and Rosetta on Apple Silicon
# can emulate x86_64 correctly when the full x86_64 base image is used.
FROM --platform=linux/amd64 mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG AFTMAN_VERSION=0.3.0

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    ca-certificates \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Aftman (Roblox toolchain manager)
RUN curl -Lo /tmp/aftman.zip \
    "https://github.com/LPGhatguy/aftman/releases/download/v${AFTMAN_VERSION}/aftman-${AFTMAN_VERSION}-linux-x86_64.zip" \
    && unzip /tmp/aftman.zip -d /usr/local/bin \
    && chmod +x /usr/local/bin/aftman \
    && rm /tmp/aftman.zip

# Switch to vscode user and install tools from aftman.toml into the image
USER vscode
ENV PATH="/home/vscode/.aftman/bin:${PATH}"

WORKDIR /tmp/aftman-setup
COPY --chown=vscode:vscode aftman.toml ./
RUN aftman install --no-trust-check && rm aftman.toml

WORKDIR /workspaces
