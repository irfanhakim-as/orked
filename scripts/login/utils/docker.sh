#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SCRIPT_PATH="${SOURCE_DIR}/../.."

# variables
PKG_NAME="docker"

if [ "$(bash "${SCRIPT_PATH}/utils.sh" --is-installed ${PKG_NAME})" = "false" ]; then
    echo "Installing ${PKG_NAME}..."
    # run installer
    bash "${SCRIPT_PATH}/utils.sh" --sudo "curl https://releases.rancher.com/install-docker/20.10.sh | sh"
    # create group docker
    bash "${SCRIPT_PATH}/utils.sh" --sudo groupadd docker
    # add current user to docker group
    bash "${SCRIPT_PATH}/utils.sh" --sudo usermod -aG docker "${USER}"
    # enable docker service
    bash "${SCRIPT_PATH}/utils.sh" --sudo systemctl enable --now docker
else
    echo "${PKG_NAME} is already installed"
fi