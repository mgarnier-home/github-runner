#!/bin/bash
set -euo pipefail

function configure_docker() {
  # shellcheck source=/dev/null
  source /etc/os-release

  mkdir -p /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/$ID/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  local version DPKG_ARCH
  version=$(echo "$VERSION_CODENAME" | sed 's/trixie\|n\/a/bookworm/g')
  DPKG_ARCH="$(dpkg --print-architecture)"
  echo "deb [arch=${DPKG_ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$ID ${version} stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
}

function configure_gh_cli() {
  (type -p wget >/dev/null || (apt update && apt install wget -y)) \
	&& mkdir -p -m 755 /etc/apt/keyrings \
	&& out=$(mktemp) && wget -nv -O "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat "$out" | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& mkdir -p -m 755 /etc/apt/sources.list.d \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
}

function install_prerequisites() {
  apt-get update

  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  gnupg \
  tar \
  unzip \
  zip \
  apt-transport-https \
  sudo \
  dirmngr \
  locales \
  gosu \
  git \
  gpg-agent \
  dumb-init \
  libc-bin \
  pass \
  sshpass \
  zip \
  openssh-client \
  jq \
  gnupg2
}


function install_docker() {
  apt-get install -y docker-ce docker-ce-cli docker-buildx-plugin containerd.io docker-compose-plugin --no-install-recommends --allow-unauthenticated

  echo -e '#!/bin/sh\ndocker compose --compatibility "$@"' > /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose

  sed -i 's/ulimit -Hn/# ulimit -Hn/g' /etc/init.d/docker
}

function configure_docker_credential_helpers() {
  wget -O docker-credential-pass https://github.com/docker/docker-credential-helpers/releases/download/v0.9.4/docker-credential-pass-v0.9.4.linux-amd64
  chmod +x docker-credential-pass
  sudo mv docker-credential-pass /usr/local/bin/
}

function install_gh_cli() {
	apt install gh -y
}

function install_az_cli() {
  curl -sL https://aka.ms/InstallAzureCLIDeb | bash
}

function setup_sudoers() {
  sed -e 's/Defaults.*env_reset/Defaults env_keep = "HTTP_PROXY HTTPS_PROXY NO_PROXY FTP_PROXY http_proxy https_proxy no_proxy ftp_proxy"/' -i /etc/sudoers
  echo '%sudo ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
}

install_prerequisites

configure_gh_cli
configure_docker

apt-get update
update-ca-certificates

install_az_cli
install_gh_cli
install_docker

setup_sudoers
groupadd -g "121" runner
useradd -mr -d /home/runner -u "1001" -g "121" runner
usermod -aG sudo runner
usermod -aG docker runner

configure_docker_credential_helpers
chown -R runner:runner /home/runner

