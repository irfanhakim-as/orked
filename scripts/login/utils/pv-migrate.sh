#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# variables
export PKG_NAME="${PKG_NAME:-"pv-migrate"}"
export PKG_BIN_SRC="${PKG_BIN_SRC:-"${PKG_NAME}"}"
export PKG_REPO="${PKG_REPO:-"utkuozdemir/pv-migrate"}"
export PKG_ARCHIVE_FMT="${PKG_ARCHIVE_FMT:-"tar.gz"}"

# (mostly) constants
export SYS_ARCH="${SYS_ARCH:-"x86_64"}"
export SYS_PLATFORM="${SYS_PLATFORM:-"linux"}"
export INSTALL_PFX="${INSTALL_PFX:-"/usr/local"}"
export PKG_BIN="${PKG_BIN:-"$(basename "${PKG_BIN_SRC}")"}"
export PKG_API_URL="https://api.github.com/repos/${PKG_REPO}/releases/latest"
export PKG_DL_URL="https://github.com/${PKG_REPO}/releases/download"
export PKG_LATEST_VER=$(curl -s "${PKG_API_URL}" | perl -lne 'print $& if /"tag_name": "v\K[0-9.]+/')
export PKG_SRC_VER="${PKG_SRC_VER:-"${PKG_LATEST_VER}"}"
export PKG_SRC_ARCHIVE="${PKG_NAME}_v${PKG_SRC_VER}_${SYS_PLATFORM}_${SYS_ARCH}.${PKG_ARCHIVE_FMT}"
export PKG_SRC_URL="${PKG_DL_URL}/v${PKG_SRC_VER}/${PKG_SRC_ARCHIVE}"
export PKG_TMP_ARCHIVE="/tmp/${PKG_SRC_ARCHIVE}"
export PKG_TMP_DIR=$(dirname "${PKG_TMP_ARCHIVE}")
export PKG_INSTALL_DIR="${INSTALL_PFX}/bin"


# ================= DO NOT EDIT BEYOND THIS LINE =================

# get arguments
while [[ ${#} -gt 0 ]]; do
    case "${1}" in
        -f|--force)
            export PKG_FORCE_INSTALL=true
            ;;
        -r|--remove)
            export PKG_REMOVE=true
            ;;
        *)
            echo "Invalid argument: ${1}"
            exit 1
            ;;
    esac
    shift
done

bash "${SOURCE_DIR}/generic-installer.sh"