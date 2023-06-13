#!/bin/bash

# get data from user input
function get_data() {
    read -p "Enter ${1}: " data
    echo -n "${data}"
}

# get password from user input
function get_password() {
    read -s password
    echo -n "${password}"
}

# get secret from user input and encode it to base64
function get_secret() {
    read -p "Enter ${1}: " secret
    echo -n "${secret}" | base64
}

# function to get multiple values from user input
function get_values() {
    values=()
    index=0
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

# check if a command is installed
function is_installed() {
    if ! [ -x "$(command -v ${1})" ]; then
        return 1
    else
        return 0
    fi
}

# update config file
function update_config() {
    file=${1}
    key=${2}
    value=${3}

    # check if the key exists in the file
    if grep -q "^${key}=" "${file}"; then
        # update its value if key exists
        sed -i "s/^${key}=.*/${key}=${value}/" "${file}"
    else
        # create the key-value pair if key does not exist
        echo -ne "\n${key}=${value}" >> "${file}"
    fi
}

# wait until no pods are pending
function wait_for_pods() {
    namespace="${1}"
    name="${2}"
    while true; do
        pods=$(kubectl get pods -n ${namespace} | grep "${name}" | grep 'Pending' | wc -l)
        if [ "${pods}" -eq 0 ]; then
            echo "All pods in ${namespace} are ready!"
            break
        else
            echo "Waiting for pods to be ready..."
            sleep 5
        fi
    done
}

# print help message
function print_help() {
    echo "Usage: $0 [OPTIONS]"; echo
    echo "OPTIONS:"
    echo "      --get-data              Get user input as data."
    echo "      --get-password          Get user input as password."
    echo "      --get-secret            Get user input and encode to base64."
    echo "      --get-values            Get multiple user values for an array."
    echo "      --is-installed          Check if a command is installed."
    echo "      --update-config         Update/add a key-value pair in a config file."
    echo "      --wait-for-pods         Wait until no pods are pending."
    echo "  -h, --help                  Show this help message."; echo
    echo "Report bugs to https://github.com/irfanhakim-as/orked/issues"
}

# get arguments on what function to run
while [[ $# -gt 0 ]]; do
    case "${1}" in
        --get-data)
            if [ -z "${2}" ]; then
                echo "Please provide information of the data you are requesting!"
                exit 1
            fi
            get_data "${2}"
            shift
            ;;
        --get-password)
            get_password
            shift
            ;;
        --get-secret)
            if [ -z "${2}" ]; then
                echo "Please provide information of the secret you are requesting!"
                exit 1
            fi
            get_secret "${2}"
            shift
            ;;
        --get-values)
            if [ -z "${2}" ]; then
                echo "Please provide information of what you are requesting!"
                exit 1
            fi
            get_values "${2}"
            shift
            ;;
        --is-installed)
            if [ -z "${2}" ]; then
                echo "Please provide the command you wish to check!"
                exit 1
            fi
            is_installed "${2}"
            shift
            ;;
        --update-config)
            if [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ]; then
                echo "Please provide the file, key, and value you wish to update!"
                exit 1
            fi
            update_config "${2}" "${3}" "${4}"
            shift 3
            ;;
        --wait-for-pods)
            if [ -z "${2}" ]; then
                echo "Please provide a namespace!"
                exit 1
            fi
            wait_for_pods "${2}" "${3}"
            shift 2
            ;;
        -h|--help)
            print_help
            shift
            ;;
        *)
            echo "Invalid argument: ${1}"
            exit 1
            ;;
    esac
    shift
done