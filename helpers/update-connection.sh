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
echo ${sudo_password} | sudo -S bash -c "nmcli connection up ${interface}"

# backup connection config
echo ${sudo_password} | sudo -S bash -c "cp -f ${config_file} ${config_file}.bak"

# update connection config
echo ${sudo_password} | sudo -S bash -c "update_config ${config_file} 'BOOTPROTO' \"${bootproto}\""
echo ${sudo_password} | sudo -S bash -c "update_config ${config_file} 'IPV6INIT' \"${ipv6init}\""
echo ${sudo_password} | sudo -S bash -c "update_config ${config_file} 'IPV6_AUTOCONF' \"${ipv6_autoconf}\""
echo ${sudo_password} | sudo -S bash -c "update_config ${config_file} 'ONBOOT' \"${onboot}\""
echo ${sudo_password} | sudo -S bash -c "update_config ${config_file} 'IPADDR' \"${ipaddr}\""
echo ${sudo_password} | sudo -S bash -c "update_config ${config_file} 'PREFIX' \"${prefix}\""
echo ${sudo_password} | sudo -S bash -c "update_config ${config_file} 'GATEWAY' \"${gateway}\""
echo ${sudo_password} | sudo -S bash -c "update_config ${config_file} 'DNS1' \"${dns1}\""
echo ${sudo_password} | sudo -S bash -c "update_config ${config_file} 'DNS2' \"${dns2}\""

# restart network
echo ${sudo_password} | sudo -S bash -c "systemctl restart NetworkManager"

# reboot
echo ${sudo_password} | sudo -S bash -c "reboot now"