#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="${SOURCE_DIR}/../../.."
SCRIPT_DIR="${ROOT_DIR}/scripts"
DEP_DIR="${ROOT_DIR}/deps"

# source project files
source "${SCRIPT_DIR}/utils.sh"

# variables
PKG_NAME="helm"


# ================= DO NOT EDIT BEYOND THIS LINE =================

if [ "$(is_installed "${PKG_NAME}")" = "false" ]; then
    echo "Installing ${PKG_NAME}..."
    # run installer
    # source: https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    run_with_sudo bash "${DEP_DIR}/login/helm.sh"
else
    echo "${PKG_NAME} is already installed"
fi