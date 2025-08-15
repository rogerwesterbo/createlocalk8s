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

function check_docker_hub_login() {
    echo -e "$yellow\n🔍 Checking Docker Hub login status..."
    
    if ! docker info >/dev/null 2>&1; then
        echo -e "$red\n🚨 Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    # Check if user is logged in by trying to get username from docker info
    local username=$(docker info 2>/dev/null | grep -i "Username:" | awk '{print $2}' | tr -d ' ')
    
    if [[ -n "$username" ]]; then
        echo -e "$green\n✅ Logged into Docker Hub as: $username"
        return 0
    fi
    
    # Alternative check: try to get username using docker system info
    local username_alt=$(docker system info --format '{{.Username}}' 2>/dev/null)
    if [[ -n "$username_alt" ]]; then
        echo -e "$green\n✅ Logged into Docker Hub as: $username_alt"
        return 0
    fi
    
    # If no username found, user is not logged in
    echo -e "$red\n🚨 You are not logged into Docker Hub!"
    echo -e "$yellow\nTo login to Docker Hub, run:"
    echo -e "$blue docker login"
    echo -e "$yellow\nThen enter your Docker Hub username and password."
    exit 1
}