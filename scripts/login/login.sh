#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# get sudo password
echo "Enter sudo password:"
export sudo_password=$(bash "${SOURCE_DIR}/utils.sh" --get-password)

# setup yum repo and dependencies
bash "${SOURCE_DIR}/yum.sh"

# install docker
bash "${SOURCE_DIR}/docker.sh"

# install kubectl
bash "${SOURCE_DIR}/kubectl.sh"

# install kubectx and kubens
bash "${SOURCE_DIR}/kubectx.sh" && PKG_NAME="kubens" bash "${SOURCE_DIR}/kubectx.sh"

# install k9s
PKG_SRC_VER="0.26.4" bash "${SOURCE_DIR}/k9s.sh"

# install helm
if [ "$(bash "${SOURCE_DIR}/utils.sh" --is-installed helm)" = "true" ]; then
    echo "Helm is already installed"
else
    echo ${sudo_password} | sudo -S bash -c "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
fi

# install pv-migrate
bash "${SOURCE_DIR}/pv-migrate.sh"

# install df-pv
bash "${SOURCE_DIR}/df-pv.sh"

# reboot
bash "${SCRIPT_PATH}/utils.sh" --sudo reboot now