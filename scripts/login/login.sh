#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="${SOURCE_DIR}/../.."
SCRIPT_DIR="${ROOT_DIR}/scripts"
UTILS_DIR="${SOURCE_DIR}/utils"
ENV_FILE="${ENV_FILE:-"${ROOT_DIR}/.env"}"

# source project files
if [ -f "${ENV_FILE}" ]; then
    source "${ENV_FILE}"
fi
source "${SCRIPT_DIR}/utils.sh"

# print title
print_title "login node"

# variables
export SUDO_PASSWD="${SUDO_PASSWD:-"$(get_password "sudo password")"}"

# env variables
env_variables=(
    "SUDO_PASSWD"
)

# ================= DO NOT EDIT BEYOND THIS LINE =================

# get user confirmation
confirm_values "${env_variables[@]}"
confirm="${?}"
if [ "${confirm}" -ne 0 ]; then
    exit "${confirm}"
fi

# setup yum repo and dependencies
bash "${UTILS_DIR}/yum.sh"

# install docker
bash "${UTILS_DIR}/docker.sh"

# install kubectl
bash "${UTILS_DIR}/kubectl.sh"

# install kubectx and kubens
bash "${UTILS_DIR}/kubectx.sh" && PKG_NAME="kubens" bash "${UTILS_DIR}/kubectx.sh"

# install k9s
SYS_ARCH="x86_64" PKG_SRC_VER="0.26.4" bash "${UTILS_DIR}/k9s.sh"

# install helm
bash "${UTILS_DIR}/helm.sh"

# install pv-migrate
bash "${UTILS_DIR}/pv-migrate.sh"

# install df-pv
bash "${UTILS_DIR}/df-pv.sh"

# reboot
run_with_sudo reboot now