#!/usr/bin/env bash
#
# Script to run Docker image localy

#+----------------------------------------------------------------------------------------------------------+
# Configure script execute options
set -euo pipefail

# DESC: Usage help
# ARGS: None
# OUTS: None
function printScriptUsage() {
    cat << EOF
Usage: ./$(basename $BASH_SOURCE)[options]
     -h | --help: display this help
     -v | --verbose: display more infos
     -i | --imagename: Docker image name to use. Defaut: cbna/gentiana-data.
     -n | --network: Docker network name to use. Default: geonature-local_default.
     -e | --entrypoint: define an entrypoint to use with Docker.
EOF
    exit 0
}

# DESC: Parameter parser
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: Variables indicating command-line parameters and options
function parseScriptOptions() {
    # Transform long options to short ones
    for arg in "${@}"; do
        shift
        case "${arg}" in
            "--help") set -- "${@}" "-h" ;;
            "--verbose") set -- "${@}" "-v" ;;
            "--imagename") set -- "${@}" "-i" ;;
            "--network") set -- "${@}" "-n" ;;
            "--entrypoint") set -- "${@}" "-e" ;;
            "--"*) echo -e "\e[1;31mERROR : parameter '${arg}' invalid ! Use -h option to know more.\e[0m"; exit 1 ;;
            *) set -- "${@}" "${arg}"
        esac
    done

    while getopts "hvn:i:e:" option; do
        case "${option}" in
            "h") printScriptUsage ;;
            "v") readonly verbose=true ;;
            "i") readonly image_name="${OPTARG}" ;;
            "n") readonly container_network="${OPTARG}" ;;
            "e") readonly container_entrypoint="${OPTARG}" ;;
            *) echo -e "\e[1;31mERROR : parameter invalid ! Use -h option to know more.\e[0m"; exit 1 ;;
        esac
    done

    # Default value
    if [[ -z "${verbose:-}" ]]; then
        readonly verbose=false
    fi
    if [[ -z "${image_name:-}" ]]; then
        readonly image_name="cbna/gentiana-data"
    fi
    if [[ -z "${container_network:-}" ]]; then
        readonly container_network="geonature-local-db-net"
    fi
    if [[ -z "${container_entrypoint:-}" ]]; then
        readonly container_entrypoint=""
    fi
}

# DESC: Main control flow
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
function main() {
    parseScriptOptions "${@}"

    runDockerImage "${@}"
}

function runDockerImage() {
    local uid=$(id -u)
    local gid=$(id -g)
    local build_current_modified_files_nbr=$(git status -s -uno | wc -l)
    local build_status=$(( [ "${build_current_modified_files_nbr}" != "0" ] && echo "-dirty") || echo "")
    local image_version="$(git describe --tag --exact-match 2> /dev/null || git rev-parse --abbrev-ref HEAD)${build_status}"
    local image_fullname="${image_name:-"cbna/gentiana-data"}:${image_version}"
    local entrypoint=""
    if [[ -n "${container_entrypoint}" ]]; then
        entrypoint="--entrypoint ${container_entrypoint}"
    fi
    local container_args=""
    if [[ -z "${container_entrypoint}" ]] && [[ -n "${verbose}" ]]; then
        container_args="-v"
    fi

    # -v "${HOME}.ssh/:/home/geonat/.ssh/" \
    # -v "$PWD/geonature/var/":/app/geonature/var/ \
    docker run --rm \
        -a stdin -a stdout -a stderr \
        --user ${uid}:${gid} \
        -v "$PWD/geonature/config/settings.ini":/app/geonature/config/settings.ini \
        -v "$PWD/shared/config/settings.ini":/app/shared/config/settings.ini \
        -v "$PWD/geonature/data/raw/":/app/geonature/data/raw/ \
        -v "$PWD/geonature/var/":/app/geonature/var/ \
        --network "${container_network}" \
        ${entrypoint} \
        -it "${image_fullname}" \
        ${container_args}
}

main "${@}"
