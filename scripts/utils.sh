#!/bin/bash

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

# wait until no pods are pending
function wait_for_pods() {
    namespace="${1}"
    name="${2}"
    while true; do
        pods=$(kubectl get pods ${name} -n ${namespace} | grep 'Pending' | wc -l)
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
    echo "      --get-values            Get multiple user values for an array."
    echo "      --wait-for-pods         Wait until no pods are pending."
    echo "  -h, --help                  Show this help message."; echo
    echo "Report bugs to https://github.com/irfanhakim-as/orked/issues"
}

# get arguments on what function to run
while [[ $# -gt 0 ]]; do
    case "${1}" in
        --get-values)
            if [ -z "${2}" ]; then
                echo "Please provide information of what you are requesting!"
                exit 1
            fi
            get_values "${2}"
            shift
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