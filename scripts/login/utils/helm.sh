#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SCRIPT_PATH="${SOURCE_DIR}/../.."
DEP_PATH="${SOURCE_DIR}/../../../deps"

# source project files
source "${SCRIPT_PATH}/utils.sh"

# variables
PKG_NAME="helm"


# ================= DO NOT EDIT BEYOND THIS LINE =================

if [ "$(is_installed "${PKG_NAME}")" = "false" ]; then
    echo "Installing ${PKG_NAME}..."
    # run installer
    # source: https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    run_with_sudo bash "${DEP_PATH}/login/helm.sh"
else
    echo "${PKG_NAME} is already installed"
fi