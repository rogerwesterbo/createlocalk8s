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

function print_logo() {
    echo -e "$blue"

    echo ""
    echo " ▄████▄   ██▀███  ▓█████ ▄▄▄     ▄▄▄█████▓▓█████     ▄████▄   ██▓     █    ██   ██████ ▄▄▄█████▓▓█████  ██▀███  ";
    echo "▒██▀ ▀█  ▓██ ▒ ██▒▓█   ▀▒████▄   ▓  ██▒ ▓▒▓█   ▀    ▒██▀ ▀█  ▓██▒     ██  ▓██▒▒██    ▒ ▓  ██▒ ▓▒▓█   ▀ ▓██ ▒ ██▒";
    echo "▒▓█    ▄ ▓██ ░▄█ ▒▒███  ▒██  ▀█▄ ▒ ▓██░ ▒░▒███      ▒▓█    ▄ ▒██░    ▓██  ▒██░░ ▓██▄   ▒ ▓██░ ▒░▒███   ▓██ ░▄█ ▒";
    echo "▒▓▓▄ ▄██▒▒██▀▀█▄  ▒▓█  ▄░██▄▄▄▄██░ ▓██▓ ░ ▒▓█  ▄    ▒▓▓▄ ▄██▒▒██░    ▓▓█  ░██░  ▒   ██▒░ ▓██▓ ░ ▒▓█  ▄ ▒██▀▀█▄  ";
    echo "▒ ▓███▀ ░░██▓ ▒██▒░▒████▒▓█   ▓██▒ ▒██▒ ░ ░▒████▒   ▒ ▓███▀ ░░██████▒▒▒█████▓ ▒██████▒▒  ▒██▒ ░ ░▒████▒░██▓ ▒██▒";
    echo "░ ░▒ ▒  ░░ ▒▓ ░▒▓░░░ ▒░ ░▒▒   ▓▒█░ ▒ ░░   ░░ ▒░ ░   ░ ░▒ ▒  ░░ ▒░▓  ░░▒▓▒ ▒ ▒ ▒ ▒▓▒ ▒ ░  ▒ ░░   ░░ ▒░ ░░ ▒▓ ░▒▓░";
    echo "  ░  ▒     ░▒ ░ ▒░ ░ ░  ░ ▒   ▒▒ ░   ░     ░ ░  ░     ░  ▒   ░ ░ ▒  ░░░▒░ ░ ░ ░ ░▒  ░ ░    ░     ░ ░  ░  ░▒ ░ ▒░";
    echo "░          ░░   ░    ░    ░   ▒    ░         ░      ░          ░ ░    ░░░ ░ ░ ░  ░  ░    ░         ░     ░░   ░ ";
    echo "░ ░         ░        ░  ░     ░  ░           ░  ░   ░ ░          ░  ░   ░           ░              ░  ░   ░     ";
    echo "░                                                   ░                                                           ";
    echo ""
}

function print_help() {
    # Display Help
    echo -e "$yellow"
    echo "Kind spesific:"    
    echo "  create                    alias: c       Create a local cluster with kind and docker"
    echo "  list                      alias: ls      Show kind clusters"
    echo "  details                   alias: dt      Show details for a cluster"
    echo "  kubeconfig                alias: kc      Get kubeconfig for a cluster by name"
    echo "  delete                    alias: d       Delete a cluster by name"
    echo "  help                      alias: h       Print this Help"
    echo ""
    echo "Helm:"
    echo "  install-helm-argocd        alias: iha     Install ArgoCD with helm"
    echo "  install-crossplane         alias: ihcr    Install Crossplane with helm"
    echo "  install-helm-ceph-operator alias: ihrco   Install Rook Ceph Operator with helm"
    echo "  install-helm-ceph-cluster  alias: ihrcc   Install Rook Ceph Cluster with helm"
    echo "  install-helm-falco         alias: ihf     Install Falco with helm"
    echo "  install-helm-nginx         alias: ihn     Install Nginx controller with helm"
    echo "  install-helm-metallb       alias: ihm     Install Metallb with helm"
    echo "  install-helm-minio         alias: ihmin   Install Minio with helm"
    echo "  install-helm-mongodb       alias: ihmdb   Install Mongodb with helm"
    echo "  install-helm-openebs       alias: ihoe    Install OpenEBS with helm"
    echo "  install-helm-postgres      alias: ihpg    Install Cloud Native Postgres Operator with helm"
    echo "  install-helm-pgadmin       alias: ihpa    Install PgAdmin4 with helm"
    echo "  install-helm-trivy         alias: iht     Install Trivy Operator with helm"
    echo "  install-helm-vault         alias: ihv     Install Vault with helm"
    echo ""
    echo "ArgoCD Applications:"
    echo "  install-app-ceph-operator alias: iarco   Install Rook Ceph Operator ArgoCD application"
    echo "  install-app-ceph-cluster  alias: iarcc   Install Rook Ceph Cluster ArgoCD application"
    echo "  install-app-certmanager   alias: iacm    Install Cert-manager ArgoCD application"
    echo "  install-app-crossplane    alias: iacr    Install Crossplane ArgoCD application"
    echo "  install-app-falco         alias: iaf     Install Falco ArgoCD application"
    echo "  install-app-kubeview      alias: iakv    Install Kubeview ArgoCD application"
    echo "  install-app-nginx         alias: ian     Install Nginx Controller ArgoCD application"
    echo "  install-app-minio         alias: iamin   Install Minio ArgoCD application"
    echo "  install-app-mongodb       alias: iamdb   Install Mongodb ArgoCD application"
    echo "  install-app-nyancat       alias: iac     Install Nyan-cat ArgoCD application"
    echo "  install-app-openebs       alias: iaoe    Install OpenEBS ArgoCD application"
    echo "  install-app-opencost      alias: iaoc    Install OpenCost ArgoCD application"
    echo "  install-app-postgres      alias: iapg    Install Cloud Native Postgres Operator ArgoCD application"
    echo "  install-app-pgadmin       alias: iapga   Install PgAdmin4 ArgoCD application"
    echo "  install-app-prometheus    alias: iap     Install Kube-prometheus-stack ArgoCD application"
    
    echo "  install-app-metallb       alias: iam     Install Metallb ArgoCD application"
    echo "  install-app-trivy         alias: iat     Install Trivy Operator ArgoCD application"
    echo "  install-app-vault         alias: iav     Install Hashicorp Vault ArgoCD application"
    echo ""
    echo "dependencies: docker, kind, kubectl, jq, base64 and helm"
    echo ""
    now=$(date)
    printf "Current date and time in Linux %s\n" "$now"
    echo ""
}

function is_running_more_than_one_cluster() {
    local clusters
    clusters=$(kind get clusters -q)

    return_statement="no"

    if [ "$clusters" == "No kind clusters found." ]; then
        #echo "no"
        #echo "no kind clusters found."
        return_statement="no"
    elif [ -z "$clusters" ]; then
        #echo "no"
        #echo "cluster is empty"
        return_statement="no"
    elif [[ $(echo "$clusters" | wc -l) -ge 1 ]]; then
        #echo "no"
        #echo "yes - one cluster"
        return_statement="no"
    # else
    #     echo "yes - one cluster"
    elif [[ $(echo "$clusters" | wc -l) -ge 2 ]]; then
        #echo "yes"
        #echo "yes - more than one cluster"
        return_statement="yes"
    fi

    echo "$return_statement"
}

check_kind_clusters() {
    # Try to run the command and capture output
    local output
    if output=$(kind get clusters -q); then
        # Command succeeded, you can process $output internally
        #echo "Clusters found: $output"  # optional internal echo

        if [[ "$output" == "No kind clusters found." ]]; then
            # No clusters found
            echo "No kind clusters found."
            return 0
        elif [[ -z "$output" ]]; then
            # Cluster list is empty
            echo "Cluster list is empty."
            return 0
        elif [[ $(echo "$output" | wc -l) -eq 1 ]]; then
            # Exactly one cluster found
            echo "Exactly one kind cluster found."
            return 1
        elif [[ $(echo "$output" | wc -l) -ge 1 ]]; then
            # One or more clusters found
            echo "One or more kind clusters found."
            return 1
        elif [[ $(echo "$output" | wc -l) -ge 2 ]]; then
            # More than one cluster found
            echo "More than one kind cluster found."
            return 1
        else
            # Unexpected output
            echo "Unexpected output: $output"
            return 1
        fi


        return 0
    else
        # Command failed
        return 0
    fi
}