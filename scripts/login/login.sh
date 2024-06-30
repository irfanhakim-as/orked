#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SCRIPT_PATH="${SOURCE_DIR}/.."
UTILS_PATH="${SOURCE_DIR}/utils"

# get sudo password
echo "Enter sudo password:"
export sudo_password=$(bash "${SCRIPT_PATH}/utils.sh" --get-password)

# setup yum repo and dependencies
bash "${UTILS_PATH}/yum.sh"

# install docker
bash "${UTILS_PATH}/docker.sh"

# install kubectl
bash "${UTILS_PATH}/kubectl.sh"

# install kubectx and kubens
bash "${UTILS_PATH}/kubectx.sh" && PKG_NAME="kubens" bash "${UTILS_PATH}/kubectx.sh"

# install k9s
PKG_SRC_VER="0.26.4" bash "${UTILS_PATH}/k9s.sh"

# install helm
if [ "$(bash "${SCRIPT_PATH}/utils.sh" --is-installed helm)" = "true" ]; then
    echo "Helm is already installed"
else
    echo ${sudo_password} | sudo -S bash -c "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
fi

# install pv-migrate
bash "${UTILS_PATH}/pv-migrate.sh"

# install df-pv
bash "${UTILS_PATH}/df-pv.sh"

# reboot
bash "${SCRIPT_PATH}/utils.sh" --sudo reboot now