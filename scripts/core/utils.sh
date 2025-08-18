#!/bin/bash

function die () {
    ec=$1
    kill $$
}

# Fallback color variables (in case variables.sh not sourced yet or linter complaints)
: "${yellow:=}"
: "${blue:=}"
: "${red:=}"
: "${green:=}"
: "${clear:=}"

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

function ensure_docker_running() {
    # Verifies docker daemon availability before any login / image operations
    if ! docker info >/dev/null 2>&1; then
        echo -e "$red\n🚨 Docker is not running. Please start Docker Desktop / daemon and try again."
        exit 1
    fi
}

function _docker_detect_login() {
    # Echo detected username (empty if none) and return 0 always
    local u1="" u2="" u3="" final_user="" raw_auth="" decoded=""
    # Force C locale for consistent parsing preventing illegal byte sequence issues
    export LC_ALL=C LANG=C
    u1=$(docker info 2>/dev/null | awk -F': *' 'tolower($1)=="username" {print $2; exit}' | tr -d ' ')
    if [[ -z "$u1" ]]; then
        u2=$(docker info --format '{{.Username}}' 2>/dev/null | tr -d ' ')
    fi
    if [[ -z "$u1" && -z "$u2" && -f "$HOME/.docker/config.json" ]]; then
        if command -v jq >/dev/null 2>&1; then
            # Look for docker hub style keys
            raw_auth=$(jq -r '.auths | to_entries[] | select(.key|test("docker.io")) | .value.auth' "$HOME/.docker/config.json" 2>/dev/null | head -n1)
            if [[ "$raw_auth" == "null" ]]; then raw_auth=""; fi
            # Only attempt decode if it looks like base64
            if [[ -n "$raw_auth" && "$raw_auth" =~ ^[A-Za-z0-9+/=]+$ ]]; then
                decoded=$(printf '%s' "$raw_auth" | LC_ALL=C base64 --decode 2>/dev/null || true)
                # Expect format user:pass
                if [[ "$decoded" == *:* ]]; then
                    u3="${decoded%%:*}"
                fi
            fi
            # Heuristic: credential store entry without inline auth
            if [[ -z "$u1" && -z "$u2" && -z "$u3" ]]; then
                if jq -e '.auths | keys[] | select(test("docker.io"))' "$HOME/.docker/config.json" >/dev/null 2>&1; then
                    if jq -e '.credsStore // .credStore // empty' "$HOME/.docker/config.json" >/dev/null 2>&1; then
                        # We can't know username without invoking credential helper (avoid). Mark as logged in generically.
                        u3="credential-store"
                    else
                        # credHelpers per-registry?
                        if jq -e '.credHelpers | to_entries[] | .key | test("docker.io")' "$HOME/.docker/config.json" >/dev/null 2>&1; then
                            u3="credential-store"
                        fi
                    fi
                fi
            fi
        fi
    fi
    final_user="${u1:-${u2:-${u3}}}"
    echo "$final_user"
}

function check_docker_hub_login() {
    echo -e "$yellow\n🔍 Checking Docker Hub login status..."  

    # Precondition: docker daemon running (enforced earlier). If not, warn and exit.
    if ! docker info >/dev/null 2>&1; then
        echo -e "$red Docker daemon not available (this should have been caught earlier)."
        exit 1
    fi

    # Allow user to skip (e.g. CI) by setting SKIP_DOCKER_LOGIN_CHECK
    if [[ "${SKIP_DOCKER_LOGIN_CHECK}" == "yes" || "${SKIP_DOCKER_LOGIN_CHECK}" == "true" ]]; then
        echo -e "$yellow⏭  Docker login check skipped via SKIP_DOCKER_LOGIN_CHECK env var"
        return 0
    fi

    local final_user
    final_user=$(_docker_detect_login)

    if [[ -n "$final_user" ]]; then
        if [[ "$final_user" == "credential-store" ]]; then
            echo -e "$green✅ Logged into Docker Hub (credential store)$clear"
        else
            echo -e "$green✅ Logged into Docker Hub as: $final_user$clear"
        fi
        return 0
    fi

    # Additional heuristic: if rate limit headers accessible (skip heavy remote calls here).
    if [[ "${REQUIRE_DOCKER_LOGIN}" == "yes" || "${REQUIRE_DOCKER_LOGIN}" == "true" ]]; then
        echo -e "$red🚨 Not logged into Docker Hub and REQUIRE_DOCKER_LOGIN set. Run: docker login$clear"
        exit 1
    fi

    echo -e "$yellow⚠️  Not logged into Docker Hub (continuing – public images usually pull fine).$clear"
    echo -e "$yellow   To increase anonymous pull limits: $blue docker login$clear"

    if [[ "${DEBUG_DOCKER_LOGIN}" == "1" || "${DEBUG_DOCKER_LOGIN}" == "true" ]]; then
    echo -e "${yellow}[debug] Parsed username sources empty. Showing snippet of docker info:${clear}"
        docker info 2>/dev/null | grep -i -E 'username|registry' || true
        if command -v jq >/dev/null 2>&1; then
            echo -e "${yellow}[debug] Auth keys in config.json:${clear}"
            jq -r '.auths | keys[]' "$HOME/.docker/config.json" 2>/dev/null || true
        fi
    fi
    return 0
}