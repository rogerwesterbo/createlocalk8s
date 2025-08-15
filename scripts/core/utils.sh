#!/bin/bash

function die () {
    ec=$1
    kill $$
}

function get_abs_filename() {
  echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

spinner()
{
    local pid=$!
    local delay=0.25
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "$blue [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
    echo -e "$clear"
}

function check_prerequisites() {
    docker_cmd=$(prerequisites "docker")
    kind_cmd=$(prerequisites "kind")
    kubectl_cmd=$(prerequisites "kubectl")
    jq_cmd=$(prerequisites "jq")
    base64_cmd=$(prerequisites "base64")
    helm_cmd=$(prerequisites "helm")

    # Helper to trim whitespace
    trim() {
        echo "$1" | xargs
    }

    if [ -z "$(trim "$docker_cmd")" ] && [ -z "$(trim "$kind_cmd")" ] && [ -z "$(trim "$kubectl_cmd")" ] && [ -z "$(trim "$jq_cmd")" ] && [ -z "$(trim "$base64_cmd")" ] && [ -z "$(trim "$helm_cmd")" ]; then
        return
    fi

    echo -e "$red Missing prerequisites: \n"

    echo -e "$docker_cmd"
    echo -e "$kind_cmd"
    echo -e "$kubectl_cmd"
    echo -e "$jq_cmd"
    echo -e "$base64_cmd"
    echo -e "$helm_cmd"
    echo -e "$red \n🚨 One or more prerequisites are not installed. Please install them! 🚨"
    echo -e "$clear"
    exit 1
}

function prerequisites() {
  if ! command -v $1 1> /dev/null
  then
      echo -e "$red 🚨 $1 could not be found. Install it! 🚨"
  fi
}

function detect_os {
    local host_os

    case "$(uname -s)" in
      Darwin)
        host_os=darwin
        ;;
      Linux)
        host_os=linux
        ;;
      *)
        echo "Unsupported host OS.  Must be Linux or Mac OS X." >&2
        exit 1
        ;;
    esac

  if [[ -z "${host_os}" ]]; then
    return
  fi
}

function find_free_port() {
    LOW_BOUND=49152
    RANGE=16384
    while true; do
        CANDIDATE=$[$LOW_BOUND + ($RANDOM % $RANGE)]
        (echo -n >/dev/tcp/127.0.0.1/${CANDIDATE}) >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo $CANDIDATE
            break
        fi
    done
}