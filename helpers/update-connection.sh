#!/bin/bash

# get script source
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SCRIPT_PATH="${SOURCE_DIR}/../scripts"

# source project files
source "${SCRIPT_PATH}/utils.sh"


# ================= DO NOT EDIT BEYOND THIS LINE =================

# network interface
interface="ens192"

# config file
config_file="/etc/sysconfig/network-scripts/ifcfg-${interface}"

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
run_with_sudo nmcli connection up "${interface}"

# backup connection config
run_with_sudo cp -f "${config_file}" "${config_file}.bak"

# update connection config
run_with_sudo update_config "${config_file}" "BOOTPROTO" \"${bootproto}\"
run_with_sudo update_config "${config_file}" "IPV6INIT" \"${ipv6init}\"
run_with_sudo update_config "${config_file}" "IPV6_AUTOCONF" \"${ipv6_autoconf}\"
run_with_sudo update_config "${config_file}" "ONBOOT" \"${onboot}\"
run_with_sudo update_config "${config_file}" "IPADDR" \"${ipaddr}\"
run_with_sudo update_config "${config_file}" "PREFIX" \"${prefix}\"
run_with_sudo update_config "${config_file}" "GATEWAY" \"${gateway}\"
run_with_sudo update_config "${config_file}" "DNS1" \"${dns1}\"
run_with_sudo update_config "${config_file}" "DNS2" \"${dns2}\"

# restart network
run_with_sudo systemctl restart NetworkManager

# reboot
run_with_sudo reboot now