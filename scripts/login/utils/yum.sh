#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# script path
SCRIPT_PATH="${SOURCE_DIR}/../../scripts"

# update yum repo
bash "${SCRIPT_PATH}/utils.sh" --sudo yum update -y

# add EPEL repo
bash "${SCRIPT_PATH}/utils.sh" --sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

# install dependencies
xargs bash "${SCRIPT_PATH}/utils.sh" --sudo yum install -y < "${SOURCE_DIR}/yum.txt"

# clean up cache and unused dependencies
bash "${SCRIPT_PATH}/utils.sh" --sudo yum clean all -y && bash "${SCRIPT_PATH}/utils.sh" --sudo yum autoremove -y