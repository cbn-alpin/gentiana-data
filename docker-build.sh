#!/usr/bin/env bash
#
# Script to build Docker image

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
     -u | --uid: user UID to use inside container. Default: 1000.
     -g | --gid: user GID to use inside containe. Default: --uid value or 1000 if empty.
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
            "--uid") set -- "${@}" "-u" ;;
            "--gid") set -- "${@}" "-g" ;;
            "--"*) echo -e "\e[1;31mERROR : parameter '${arg}' invalid ! Use -h option to know more.\e[0m"; exit 1 ;;
            *) set -- "${@}" "${arg}"
        esac
    done

    while getopts "hvu:g:" option; do
        case "${option}" in
            "h") printScriptUsage ;;
            "v") readonly verbose=true ;;
            "u") readonly user_uid="${OPTARG}" ;;
            "g") readonly user_gid="${OPTARG}"; set -x ;;
            *) echo -e "\e[1;31mERROR : parameter invalid ! Use -h option to know more.\e[0m"; exit 1 ;;
        esac
    done

    # Default value
    if [[ -z "${verbose:-}" ]]; then
        readonly verbose=false
    fi
    if [[ -z "${user_uid:-}" ]]; then
        readonly user_uid=1000
    fi
    if [[ -z "${user_gid:-}" ]]; then
        readonly user_gid="${user_uid:-1000}"
    fi
}

# DESC: Main control flow
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
function main() {
    parseScriptOptions "${@}"

    buildDockerImage
}

function buildDockerImage() {
    local build_current_modified_files_nbr=$(git status -s -uno | wc -l)
    local build_status=$(( [ "${build_current_modified_files_nbr}" != "0" ] && echo "-dirty") || echo "")
    local build_version="$(git describe --tag --exact-match 2> /dev/null || git rev-parse --abbrev-ref HEAD)${build_status}"
    local build_date=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    local build_vcs_ref=$(git rev-parse --short HEAD)
    local image_name="cbna/gentiana-data:${build_version}"
    local uid="${user_uid}"
    local gid="${user_gid}"
    local progress=""
    if [[ "${verbose}" = true ]]; then
        progress="--progress=plain --no-cache"
    fi

    docker build \
        --build-arg BUILD_DATE=${build_date} \
        --build-arg BUILD_VERSION=${build_version} \
        --build-arg BUILD_VCS_REF=${build_vcs_ref} \
        --build-arg USER_UID=${uid} \
        --build-arg USER_GID=${gid} \
        ${progress} \
        -t "${image_name}" \
        ./
}

main "${@}"
