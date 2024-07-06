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
IFCFG_TMP_CONFIG="${IFCFG_TMP_CONFIG:-"${HOME}/$(basename "${IFCFG_CONFIG}").tmp"}"
NODE_HOSTNAME="${NODE_HOSTNAME:-"$(get_data "HOSTNAME")"}"


# ================= DO NOT EDIT BEYOND THIS LINE =================

# start connection
run_with_sudo nmcli connection up "${IFCFG_INTERFACE}"

# backup connection config
run_with_sudo cp -f "${IFCFG_CONFIG}" "${IFCFG_CONFIG}.bak"
run_with_sudo cp -f "${IFCFG_CONFIG}" "${IFCFG_TMP_CONFIG}"

# update connection config
update_config "${IFCFG_TMP_CONFIG}" "BOOTPROTO" "${IFCFG_BOOTPROTO}"
update_config "${IFCFG_TMP_CONFIG}" "IPV6INIT" "${IFCFG_IPV6INIT}"
update_config "${IFCFG_TMP_CONFIG}" "IPV6_AUTOCONF" "${IFCFG_IPV6_AUTOCONF}"
update_config "${IFCFG_TMP_CONFIG}" "ONBOOT" "${IFCFG_ONBOOT}"
update_config "${IFCFG_TMP_CONFIG}" "IPADDR" "${IFCFG_IPADDR}"
update_config "${IFCFG_TMP_CONFIG}" "PREFIX" "${IFCFG_PREFIX}"
update_config "${IFCFG_TMP_CONFIG}" "GATEWAY" "${IFCFG_GATEWAY}"
update_config "${IFCFG_TMP_CONFIG}" "DNS1" "${IFCFG_DNS1}"
update_config "${IFCFG_TMP_CONFIG}" "DNS2" "${IFCFG_DNS2}"

# overwrite connection config
run_with_sudo mv -f "${IFCFG_TMP_CONFIG}" "${IFCFG_CONFIG}"

# restart network
run_with_sudo systemctl restart NetworkManager

# update hostname
run_with_sudo hostnamectl set-hostname "${NODE_HOSTNAME}"

# reboot
run_with_sudo reboot now