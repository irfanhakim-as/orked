#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SCRIPT_PATH="${SOURCE_DIR}/../.."

# source project files
source "${SOURCE_DIR}/utils.sh"

# variables
PKG_NAME="${PKG_NAME:-"k9s"}"
PKG_BIN_SRC="${PKG_BIN_SRC:-"${PKG_NAME}"}"
PKG_REPO="${PKG_REPO:-"derailed/k9s"}"
PKG_ARCHIVE_FMT="${PKG_ARCHIVE_FMT:-"tar.gz"}"

# (mostly) constants
SYS_ARCH="${SYS_ARCH:-"amd64"}"
SYS_PLATFORM="${SYS_PLATFORM:-"Linux"}"
INSTALL_PFX="${INSTALL_PFX:-"/usr/local"}"
PKG_BIN="${PKG_BIN:-"$(basename "${PKG_BIN_SRC}")"}"
PKG_API_URL="https://api.github.com/repos/${PKG_REPO}/releases/latest"
PKG_DL_URL="https://github.com/${PKG_REPO}/releases/download"
PKG_LATEST_VER=$(curl -s "${PKG_API_URL}" | perl -lne 'print $& if /"tag_name": "v\K[0-9.]+/')
PKG_SRC_VER="${PKG_SRC_VER:-"${PKG_LATEST_VER}"}"
PKG_SRC_ARCHIVE="${PKG_NAME}_${SYS_PLATFORM}_${SYS_ARCH}.${PKG_ARCHIVE_FMT}"
PKG_SRC_URL="${PKG_DL_URL}/v${PKG_SRC_VER}/${PKG_SRC_ARCHIVE}"
PKG_TMP_ARCHIVE="/tmp/${PKG_SRC_ARCHIVE}"
PKG_TMP_DIR=$(dirname "${PKG_TMP_ARCHIVE}")
PKG_INSTALL_DIR="${INSTALL_PFX}/bin"


# ================= DO NOT EDIT BEYOND THIS LINE =================

# get arguments
while [[ ${#} -gt 0 ]]; do
    case "${1}" in
        -f|--force)
            PKG_FORCE_INSTALL=true
            ;;
        -r|--remove)
            PKG_REMOVE=true
            ;;
        *)
            echo "Invalid argument: ${1}"
            exit 1
            ;;
    esac
    shift
done

if [ "$(bash "${SCRIPT_PATH}/utils.sh" --is-installed ${PKG_BIN})" = "false" ] || [ "${PKG_FORCE_INSTALL}" = true ]; then
    echo "Installing ${PKG_NAME} v${PKG_SRC_VER}..."
    # create target directories
    echo "Creating target directories..."
    sudo_if_needed mkdir -p "${PKG_TMP_DIR}" "${PKG_INSTALL_DIR}"
    # download package from source
    echo "Downloading package..."
    sudo_if_needed curl -fLo "${PKG_TMP_ARCHIVE}" "${PKG_SRC_URL}"
    # check if package was downloaded successfully
    if [ ! -e "${PKG_TMP_ARCHIVE}" ]; then
        echo "ERROR: failed to download package (${PKG_SRC_URL})"
        exit 1
    fi
    # unpack package to installation directory
    if [[ "${PKG_TMP_ARCHIVE}" == *.tar.gz ]]; then
        # requires tar
        if [ "$(bash "${SCRIPT_PATH}/utils.sh" --is-installed tar)" = "false" ]; then
            echo "ERROR: tar is not installed"
            exit 1
        fi
        echo "Unpacking package with tar..."
        sudo_if_needed tar --strip-components=1 -C "${PKG_INSTALL_DIR}" -xzf "${PKG_TMP_ARCHIVE}" "${PKG_BIN_SRC}"
    elif [[ "${PKG_TMP_ARCHIVE}" == *.zip ]]; then
        # requires unzip and zipinfo
        if [ "$(bash "${SCRIPT_PATH}/utils.sh" --is-installed unzip zipinfo)" = "false" ]; then
            echo "ERROR: unzip and/or zipinfo are not installed"
            exit 1
        fi
        echo "Unpacking package with unzip..."
        sudo_if_needed unzip -p "${PKG_TMP_ARCHIVE}" "${PKG_BIN}" > "${PKG_INSTALL_DIR}/${PKG_BIN}"
    else
        echo "ERROR: unsupported archive format (${PKG_TMP_ARCHIVE})"
        exit 1
    fi
    # clean up remnants
    echo "Cleaning up archive..."
    sudo_if_needed rm -f "${PKG_TMP_ARCHIVE}"
    # check if package was installed successfully
    if [ ! -f "${PKG_INSTALL_DIR}/${PKG_BIN}" ]; then
        echo "ERROR: installation failed"
        exit 1
    fi
    # make binary executable
    echo "Making binary executable..."
    sudo_if_needed chmod +x "${PKG_INSTALL_DIR}/${PKG_BIN}"
else
    if [ "${PKG_REMOVE}" = true ]; then
        sudo_if_needed rm -f "${PKG_INSTALL_DIR}/${PKG_BIN}"
        echo "${PKG_NAME} has been uninstalled"
    else
        echo "${PKG_NAME} is already installed"
    fi
fi