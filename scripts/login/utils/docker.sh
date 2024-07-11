#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SCRIPT_DIR="${SOURCE_DIR}/../.."
DEP_DIR="${SOURCE_DIR}/../../../deps"

# source project files
source "${SCRIPT_DIR}/utils.sh"

# variables
PKG_NAME="docker"


# ================= DO NOT EDIT BEYOND THIS LINE =================

if [ "$(is_installed "${PKG_NAME}")" = "false" ]; then
    echo "Installing ${PKG_NAME}..."
    # run installer
    # source: https://releases.rancher.com/install-docker/20.10.sh
    run_with_sudo sh "${DEP_DIR}/login/20.10.sh"
    # create group docker
    run_with_sudo groupadd docker
    # add current user to docker group
    run_with_sudo usermod -aG docker "${USER}"
    # enable docker service
    run_with_sudo systemctl enable --now docker
else
    echo "${PKG_NAME} is already installed"
fi