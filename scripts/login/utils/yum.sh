#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="${SOURCE_DIR}/../../.."
SCRIPT_DIR="${ROOT_DIR}/scripts"
DEP_DIR="${ROOT_DIR}/deps"

# source project files
source "${SCRIPT_DIR}/utils.sh"


# ================= DO NOT EDIT BEYOND THIS LINE =================

# update yum repo
run_with_sudo yum update -y

# add EPEL repo
run_with_sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

# install dependencies
run_with_sudo yum install -y $(echo $(<"${DEP_DIR}/login/yum.txt") | tr "\n" " ")

# clean up cache and unused dependencies
run_with_sudo yum clean all -y && run_with_sudo yum autoremove -y