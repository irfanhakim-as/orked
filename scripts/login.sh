#!/bin/bash

function if_installed() {
    if ! [ -x "$(command -v ${1})" ]; then
        return 1
    else
        return 0
    fi
}

# install and enable docker
if if_installed docker; then
    echo "Docker is already installed"
else
    curl https://releases.rancher.com/install-docker/20.10.sh | sh \
    && sudo usermod -aG docker ${USER} \
    && sudo systemctl enable --now docker
fi

# install git
if if_installed git; then
    echo "Git is already installed"
else
    sudo yum install -y git
fi

# install kubectl
if if_installed kubectl; then
    echo "Kubectl is already installed"
else
    curl -Lo kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && sudo mv kubectl /usr/local/bin
fi

# if both kubectx and kubens are installed, skip
if if_installed kubectx && if_installed kubens; then
    echo "Kubectx and Kubens are already installed"
else
    # install kubectx and kubens
    sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx \
    && sudo ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx \
    && sudo ln -sf /opt/kubectx/kubens /usr/local/bin/kubens
fi

# install k9s
if if_installed k9s; then
    echo "K9s is already installed"
else
    curl -Lo k9s_Linux_x86_64.tar.gz "https://github.com/derailed/k9s/releases/download/v0.27.4/k9s_Linux_amd64.tar.gz" \
    && sudo tar -C /usr/local/bin -zxf k9s_Linux_x86_64.tar.gz k9s
fi

# install helm
if if_installed helm; then
    echo "Helm is already installed"
else
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi