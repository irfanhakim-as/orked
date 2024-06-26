#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# get sudo password
echo "Enter sudo password:"
export sudo_password=$(bash "${SOURCE_DIR}/utils.sh" --get-password)

# setup yum repo and dependencies
bash "${SOURCE_DIR}/yum.sh"

# install and enable docker
if [ "$(bash "${SOURCE_DIR}/utils.sh" --is-installed docker)" = "true" ]; then
    echo "Docker is already installed"
else
    echo ${sudo_password} | sudo -S bash -c "curl https://releases.rancher.com/install-docker/20.10.sh | sh" \
    && echo ${sudo_password} | sudo -S bash -c "usermod -aG docker ${USER}" \
    && echo ${sudo_password} | sudo -S bash -c "systemctl enable --now docker"
fi

# install kubectl
if [ "$(bash "${SOURCE_DIR}/utils.sh" --is-installed kubectl)" = "true" ]; then
    echo "Kubectl is already installed"
else
    curl -Lo kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && echo ${sudo_password} | sudo -S bash -c "mv kubectl /usr/local/bin"
fi

# if both kubectx and kubens are installed, skip
if [ "$(bash "${SOURCE_DIR}/utils.sh" --is-installed kubectx)" = "true" ] && [ "$(bash "${SOURCE_DIR}/utils.sh" --is-installed kubens)" = "true" ]; then
    echo "Kubectx and Kubens are already installed"
else
    # install kubectx and kubens
    echo ${sudo_password} | sudo -S bash -c "git clone https://github.com/ahmetb/kubectx /opt/kubectx" \
    && echo ${sudo_password} | sudo -S bash -c "ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx" \
    && echo ${sudo_password} | sudo -S bash -c "ln -sf /opt/kubectx/kubens /usr/local/bin/kubens"
fi

# install k9s
if [ "$(bash "${SOURCE_DIR}/utils.sh" --is-installed k9s)" = "true" ]; then
    echo "K9s is already installed"
else
    curl -Lo k9s_Linux_x86_64.tar.gz "https://github.com/derailed/k9s/releases/download/v0.27.4/k9s_Linux_amd64.tar.gz" \
    && echo ${sudo_password} | sudo -S bash -c "tar -C /usr/local/bin -zxf k9s_Linux_x86_64.tar.gz k9s" \
    && rm -f k9s_Linux_x86_64.tar.gz
fi

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