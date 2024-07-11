#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SCRIPT_DIR="${SOURCE_DIR}/../.."

# source project files
source "${SCRIPT_DIR}/utils.sh"


# ================= DO NOT EDIT BEYOND THIS LINE =================

if [ "$(is_installed "${PKG_BIN}")" = "false" ] || [ "${PKG_FORCE_INSTALL}" = "true" ]; then
    echo "Installing ${PKG_NAME} v${PKG_SRC_VER}..."
    # create target directories
    echo "Creating target directories..."
    sudo_if_needed mkdir -p "${PKG_INSTALL_DIR}"
    # if PKG_TMP_ARCHIVE is not set
    if [ ! -n "${PKG_TMP_ARCHIVE}" ]; then
        # download package from source
        echo "Downloading package..."
        sudo_if_needed curl -fLo "${PKG_INSTALL_DIR}/${PKG_BIN}" "${PKG_SRC_URL}"
    else
        # create tmp directory
        sudo_if_needed mkdir -p "${PKG_TMP_DIR}"
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
            if [ "$(is_installed "tar")" = "false" ]; then
                echo "ERROR: tar is not installed"
                exit 1
            fi
            echo "Unpacking package with tar..."
            component_layers=$(tar -tf "${PKG_TMP_ARCHIVE}" | grep -o "\b$(basename "${PKG_BIN_SRC}")\b" | sort -u | awk -F/ "{print NF-1}")
            sudo_if_needed tar --strip-components="${component_layers}" -C "${PKG_INSTALL_DIR}" -xzf "${PKG_TMP_ARCHIVE}" "${PKG_BIN_SRC}"
        elif [[ "${PKG_TMP_ARCHIVE}" == *.zip ]]; then
            # requires unzip and zipinfo
            if [ "$(is_installed "unzip" "zipinfo")" = "false" ]; then
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
    fi
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