#!/usr/bin/env bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SCRIPT_PATH="${SOURCE_DIR}/../scripts"

# source project files
source "${SCRIPT_PATH}/utils.sh"

# variables
IFCFG_INTERFACE="${IFCFG_INTERFACE:-"ens192"}"
IFCFG_CONFIG="${IFCFG_CONFIG:-"/etc/sysconfig/network-scripts/ifcfg-${IFCFG_INTERFACE}"}"


# ================= DO NOT EDIT BEYOND THIS LINE =================

# get connection values
bootproto="none"
ipv6init="no"
ipv6_autoconf="no"
onboot="yes"
ipaddr=$(get_data "IPADDR")
prefix="8"
gateway=$(get_data "GATEWAY")
dns1="1.1.1.1"
dns2="8.8.8.8"

# get sudo password
echo "Enter sudo password:"
sudo_password=$(get_password)

# start connection
run_with_sudo nmcli connection up "${IFCFG_INTERFACE}"

# backup connection config
run_with_sudo cp -f "${IFCFG_CONFIG}" "${IFCFG_CONFIG}.bak"

# update connection config
run_with_sudo update_config "${IFCFG_CONFIG}" "BOOTPROTO" \"${bootproto}\"
run_with_sudo update_config "${IFCFG_CONFIG}" "IPV6INIT" \"${ipv6init}\"
run_with_sudo update_config "${IFCFG_CONFIG}" "IPV6_AUTOCONF" \"${ipv6_autoconf}\"
run_with_sudo update_config "${IFCFG_CONFIG}" "ONBOOT" \"${onboot}\"
run_with_sudo update_config "${IFCFG_CONFIG}" "IPADDR" \"${ipaddr}\"
run_with_sudo update_config "${IFCFG_CONFIG}" "PREFIX" \"${prefix}\"
run_with_sudo update_config "${IFCFG_CONFIG}" "GATEWAY" \"${gateway}\"
run_with_sudo update_config "${IFCFG_CONFIG}" "DNS1" \"${dns1}\"
run_with_sudo update_config "${IFCFG_CONFIG}" "DNS2" \"${dns2}\"

# restart network
run_with_sudo systemctl restart NetworkManager

# reboot
run_with_sudo reboot now