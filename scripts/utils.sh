#!/usr/bin/env bash

# check if file ends with newline
function file_ends_with_newline() {
    [[ $(tail -c1 "${1}" | wc -l) -gt 0 ]]
}

# get data from user input
function get_data() {
    local data
    while [[ -z "${data}" ]]; do
        read -p "Enter ${1}: " data
    done
    echo -n "${data}"
}

# get password from user input
function get_password() {
    local hint="${1:-"password"}"
    local password
    echo -n "Enter ${hint}: " >&2
    while [[ -z "${password}" ]]; do
        read -s password
    done
    echo >&2
    echo -n "${password}"
}

# get secret from user input and encode it to base64
function get_secret() {
    local secret
    while [[ -z "${secret}" ]]; do
        read -p "Enter ${1}: " secret
    done
    echo -n "${secret}" | base64
}

# function to get multiple values from user input
function get_values() {
    local values=()
    local index=0
    while true; do
        index=$((index+1))
        read -p "Enter ${1} ${index} [Enter to quit]: " value
        if [ -z "${value}" ]; then
            break
        fi
        values+=("${value}")
    done
    echo "${values[@]}"
}

# function to get key-value pairs from user input
function get_kv_pairs() {
    local -n dict=${1}
    local hint="${2:-"key"}"
    local index=0
    while true; do
        local value=""
        index=$((index+1))
        read -p "Enter ${hint} ${index} [Enter to quit]: " key
        if [ -z "${key}" ]; then
            break
        fi
        while [[ -z "${value}" ]]; do
            read -p "Enter value for \"${key}\": " value
        done
        dict["${key}"]="${value}"
    done
}

# function to get key-value pairs using arrays
function get_kv_arrays() {
    local -n keys_array="${1}"
    local -n values_array="${2}"
    local hint="${3:-"key"}"

    # check if both arrays are filled
    if [ "${#keys_array[@]}" -eq "${#values_array[@]}" ] && [ "${#keys_array[@]}" -gt 0 ]; then
        return
    fi

    if [ "${#keys_array[@]}" -eq 0 ]; then
        # reset values array
        values_array=()
        # get key and corresponding value
        local index=0
        while true; do
            local index=$((index + 1))
            local value=""
            read -p "Enter ${hint} ${index} [Enter to quit]: " key
            if [ -z "${key}" ]; then
                break
            fi
            while [ -z "${value}" ]; do
                read -p "Enter value for \"${key}\": " value
            done
            keys_array+=("${key}")
            values_array+=("${value}")
        done
    else
        # ensure keys have corresponding values
        for ((i = 0; i < "${#keys_array[@]}"; i++)); do
            if [ -z "${values_array[i]:-}" ]; then
                local value=""
                while [ -z "${value}" ]; do
                    read -p "Enter value for \"${keys_array[i]}\": " value
                done
                values_array[i]="${value}"
            else
                echo "\"${keys_array[i]}\": \"${values_array[i]}\""
            fi
        done
    fi
}

# confirm script values
function confirm_values() {
    local values=""
    # check if all variables are set
    for var in "${@}"; do
        if [ -z "${!var}" ]; then
            echo "ERROR: \"${var}\" has not been set"
            return 1
        fi
        values+="\$${var} = \"${!var}\"\n"
    done
    # print values
    if ! [ -z "${values}" ]; then
        echo -e "${values::-2}"
    fi
    # get user confirmation
    read -p "Would you like to continue with your supplied values? [y/N]: " -n 1 -r; echo
    if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
        return 1
    fi
    return 0
}

# check if specified commands are installed
function is_installed() {
    for cmd in "${@}"; do
        if ! command -v "${cmd}" &> /dev/null; then
            echo "false"
            return 0
        fi
    done
    echo "true"
}

# update config file
function update_config() {
    local file=${1}
    local key=${2}
    local value=${3}
    # exit if required variables are not set
    if [ -z "${file}" ] || [ -z "${key}" ] || [ -z "${value}" ]; then
        echo "WARN: required variables were not supplied"
        return 1
    fi
    # check if file exists
    if [ ! -f "${file}" ]; then
        touch "${file}"
    fi
    # check if the key exists in the file
    if grep -q "^${key}=" "${file}"; then
        # update its value if key exists
        sed -i "s/^${key}=.*/${key}=${value}/" "${file}"
    else
        # add a newline if the file is not empty and does not end with a newline
        if [ -s "${file}" ] && ! file_ends_with_newline "${file}"; then
            echo -ne "\n" >> "${file}"
        fi
        # create the key-value pair if key does not exist
        echo -ne "${key}=${value}\n" >> "${file}"
    fi
}

# update hosts file
function update_hosts() {
    local ip=${1}
    local hostname=${2}
    local file=${3:-"/etc/hosts"}
    # exit if required variables are not set
    if [ -z "${ip}" ] || [ -z "${hostname}" ]; then
        echo "WARN: required variables were not supplied"
        return 1
    fi
    # check if file exists
    if [ ! -f "${file}" ]; then
        touch "${file}"
    fi
    # check if the IP already exists in the hosts file
    if grep -q "^${ip}\s" "${file}"; then
        # update the IP line with the correct hostname
        sed -i -E "s/^(${ip})(\s|$).*/${ip}   ${hostname}/" "${file}"
    else
        # add a newline if the file is not empty and does not end with a newline
        if [ -s "${file}" ] && ! file_ends_with_newline "${file}"; then
            echo -ne "\n" >> "${file}"
        fi
        # create the hostname-IP pair if hostname does not exist
        echo -ne "${ip}   ${hostname}\n" >> "${file}"
    fi
}

# wait until no pods are pending
function wait_for_pods() {
    local namespace="${1}"
    local name="${2}"
    local jq_filter='.items[] | select((.kind == "Pod" and (.status.phase != "Running" or (.status.containerStatuses[]?.ready == false) or (.status.initContainerStatuses[]?.ready == false))) or (.kind == "Job" and .status.phase != "Succeeded"))'
    # optionally filter by name
    if ! [ -z "${name}" ]; then
        jq_filter+=" | select(.metadata.name | test(\"${name}\"))"
    fi
    while true; do
        echo "Waiting for pods in ${namespace} to be created..."
        sleep 10
        local pods=$(kubectl get pods -n "${namespace}" | grep "${name}" | wc -l)
        if [ "${pods}" -eq 0 ]; then
            echo "No pods were found in ${namespace}..."
            sleep 5
        else
            echo "Waiting for pods in ${namespace} to be ready..."
            sleep 5
            local non_ready_pods=$(kubectl get pods -n "${namespace}" -o json | jq "[${jq_filter}] | length")
            if [ "${non_ready_pods}" -eq 0 ]; then
                echo "All pods in ${namespace} are ready!"
                break
            else
                echo "There are ${non_ready_pods} non-ready pods in ${namespace}"
            fi
        fi
    done
}

# run commands with sudo
function run_with_sudo() {
    local SUDO_PWD_VAR="${SUDO_PWD_VAR:-"SUDO_PASSWD"}"
    echo "${!SUDO_PWD_VAR}" | sudo -S "${@}"
}

# run commands with sudo only if operation requires root privileges
function sudo_if_needed() {
    # "${@}" 2>/dev/null || echo "WARN: retrying with sudo" && run_with_sudo "${@}" && echo "INFO: succeeded with sudo"
    if ! "${@}"; then
        run_with_sudo "${@}"
    fi
}

# print section title
function print_title() {
    echo "+ - + - + - + - + ${1^^} + - + - + - + - +"
}

# print help message
function print_help() {
    echo "Usage: $0 [OPTIONS]"; echo
    echo "OPTIONS:"
    echo "      --file-ends-with-newline         Check if a file ends with a newline."
    echo "      --get-data                       Get user input as data."
    echo "      --get-password                   Get user input as password."
    echo "      --get-secret                     Get user input and encode to base64."
    echo "      --get-values                     Get multiple user values for an array."
    echo "      --is-installed                   Check if specified command(s) are installed."
    echo "      --sudo                           Run command(s) with sudo while reading password."
    echo "      --sudo-if-needed                 Run command(s) with sudo when required."
    echo "      --update-config                  Update/add a key-value pair in a config file."
    echo "      --wait-for-pods                  Wait until no pods are pending."
    echo "  -h, --help                           Show this help message."; echo
    echo "Report bugs to https://github.com/irfanhakim-as/orked/issues"
}

# get arguments on what function to run
# while [[ $# -gt 0 ]]; do
#     case "${1}" in
#         --file-ends-with-newline)
#             if [ -z "${2}" ]; then
#                 echo "Please provide the file you are checking!"
#                 exit 1
#             fi
#             file_ends_with_newline "${2}"
#             shift
#             ;;
#         --get-data)
#             if [ -z "${2}" ]; then
#                 echo "Please provide information of the data you are requesting!"
#                 exit 1
#             fi
#             get_data "${2}"
#             shift
#             ;;
#         --get-password)
#             get_password
#             shift
#             ;;
#         --get-secret)
#             if [ -z "${2}" ]; then
#                 echo "Please provide information of the secret you are requesting!"
#                 exit 1
#             fi
#             get_secret "${2}"
#             shift
#             ;;
#         --get-values)
#             if [ -z "${2}" ]; then
#                 echo "Please provide information of what you are requesting!"
#                 exit 1
#             fi
#             get_values "${2}"
#             shift
#             ;;
#         --is-installed)
#             if [ -z "${2}" ]; then
#                 echo "Please provide the command(s) you wish to check are installed!"
#                 exit 1
#             fi
#             is_installed "${@:2}"
#             shift
#             ;;
#         --sudo)
#             if [ -z "${2}" ]; then
#                 echo "Please provide the command(s) you wish to run with sudo!"
#                 exit 1
#             fi
#             run_with_sudo "${@:2}"
#             shift
#             ;;
#         --sudo-if-needed)
#             if [ -z "${2}" ]; then
#                 echo "Please provide the command(s) you wish to run!"
#                 exit 1
#             fi
#             sudo_if_needed "${@:2}"
#             shift
#             ;;
#         --update-config)
#             if [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ]; then
#                 echo "Please provide the file, key, and value you wish to update!"
#                 exit 1
#             fi
#             update_config "${2}" "${3}" "${4}"
#             shift 3
#             ;;
#         --wait-for-pods)
#             if [ -z "${2}" ]; then
#                 echo "Please provide a namespace!"
#                 exit 1
#             fi
#             wait_for_pods "${2}" "${3}"
#             shift 2
#             ;;
#         -h|--help)
#             print_help
#             shift
#             ;;
#         # *)
#         #     echo "Invalid argument: ${1}"
#         #     exit 1
#         #     ;;
#     esac
#     shift
# done