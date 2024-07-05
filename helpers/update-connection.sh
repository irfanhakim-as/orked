#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SCRIPT_PATH="${SOURCE_DIR}/../scripts"

# source project files
source "${SCRIPT_PATH}/utils.sh"

# variables
export SUDO_PASSWD="${SUDO_PASSWD:-"$(get_password "sudo password")"}"
IFCFG_INTERFACE="${IFCFG_INTERFACE:-"$(get_data "INTERFACE")"}"
IFCFG_CONFIG="${IFCFG_CONFIG:-"/etc/sysconfig/network-scripts/ifcfg-${IFCFG_INTERFACE}"}"
IFCFG_BOOTPROTO="${IFCFG_BOOTPROTO:-"none"}"
IFCFG_IPV6INIT="${IFCFG_IPV6INIT:-"no"}"
IFCFG_IPV6_AUTOCONF="${IFCFG_IPV6_AUTOCONF:-"no"}"
IFCFG_ONBOOT="${IFCFG_ONBOOT:-"yes"}"
IFCFG_IPADDR="${IFCFG_IPADDR:-"$(get_data "IPADDR")"}"
IFCFG_PREFIX="${IFCFG_PREFIX:-"8"}"
IFCFG_GATEWAY="${IFCFG_GATEWAY:-"$(get_data "GATEWAY")"}"
IFCFG_DNS1="${IFCFG_DNS1:-"1.1.1.1"}"
IFCFG_DNS2="${IFCFG_DNS2:-"8.8.8.8"}"


# ================= DO NOT EDIT BEYOND THIS LINE =================

# start connection
run_with_sudo nmcli connection up "${IFCFG_INTERFACE}"

# backup connection config
run_with_sudo cp -f "${IFCFG_CONFIG}" "${IFCFG_CONFIG}.bak"
run_with_sudo cp -f "${IFCFG_CONFIG}" "${HOME}/$(basename "${IFCFG_CONFIG}").tmp"

# update connection config
echo "${SUDO_PASSWD}" | sudo -S update_config "${IFCFG_CONFIG}" "BOOTPROTO" \"${IFCFG_BOOTPROTO}\"
echo "${SUDO_PASSWD}" | sudo -S update_config "${IFCFG_CONFIG}" "IPV6INIT" \"${IFCFG_IPV6INIT}\"
echo "${SUDO_PASSWD}" | sudo -S update_config "${IFCFG_CONFIG}" "IPV6_AUTOCONF" \"${IFCFG_IPV6_AUTOCONF}\"
echo "${SUDO_PASSWD}" | sudo -S update_config "${IFCFG_CONFIG}" "ONBOOT" \"${IFCFG_ONBOOT}\"
echo "${SUDO_PASSWD}" | sudo -S update_config "${IFCFG_CONFIG}" "IPADDR" \"${IFCFG_IPADDR}\"
echo "${SUDO_PASSWD}" | sudo -S update_config "${IFCFG_CONFIG}" "PREFIX" \"${IFCFG_PREFIX}\"
echo "${SUDO_PASSWD}" | sudo -S update_config "${IFCFG_CONFIG}" "GATEWAY" \"${IFCFG_GATEWAY}\"
echo "${SUDO_PASSWD}" | sudo -S update_config "${IFCFG_CONFIG}" "DNS1" \"${IFCFG_DNS1}\"
echo "${SUDO_PASSWD}" | sudo -S update_config "${IFCFG_CONFIG}" "DNS2" \"${IFCFG_DNS2}\"

# restart network
run_with_sudo systemctl restart NetworkManager

# reboot
run_with_sudo reboot now