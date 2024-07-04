#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SCRIPT_PATH="${SOURCE_DIR}/../scripts"

# source project files
source "${SCRIPT_PATH}/utils.sh"

# variables
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

# get sudo password
echo "Enter sudo password:"
export sudo_password="$(get_password)"

# start connection
run_with_sudo nmcli connection up "${IFCFG_INTERFACE}"

# backup connection config
run_with_sudo cp -f "${IFCFG_CONFIG}" "${IFCFG_CONFIG}.bak"

# update connection config
run_with_sudo update_config "${IFCFG_CONFIG}" "BOOTPROTO" \"${IFCFG_BOOTPROTO}\"
run_with_sudo update_config "${IFCFG_CONFIG}" "IPV6INIT" \"${IFCFG_IPV6INIT}\"
run_with_sudo update_config "${IFCFG_CONFIG}" "IPV6_AUTOCONF" \"${IFCFG_IPV6_AUTOCONF}\"
run_with_sudo update_config "${IFCFG_CONFIG}" "ONBOOT" \"${IFCFG_ONBOOT}\"
run_with_sudo update_config "${IFCFG_CONFIG}" "IPADDR" \"${IFCFG_IPADDR}\"
run_with_sudo update_config "${IFCFG_CONFIG}" "PREFIX" \"${IFCFG_PREFIX}\"
run_with_sudo update_config "${IFCFG_CONFIG}" "GATEWAY" \"${IFCFG_GATEWAY}\"
run_with_sudo update_config "${IFCFG_CONFIG}" "DNS1" \"${IFCFG_DNS1}\"
run_with_sudo update_config "${IFCFG_CONFIG}" "DNS2" \"${IFCFG_DNS2}\"

# restart network
run_with_sudo systemctl restart NetworkManager

# reboot
run_with_sudo reboot now