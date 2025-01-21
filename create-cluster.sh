#!/bin/bash

function get_abs_filename() {
  # $1 : relative filename
  echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

function die () {
    ec=$1
    kill $$
}

# global variables
scriptDir=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
configDir=$(get_abs_filename "$scriptDir/config")
cluster_name="testcluster"
worker_number=0
controlplane_number=1
install_nginx_controller="yes"
install_argocd="yes"
kind_config_path=$(get_abs_filename "$configDir/kindconfig.yaml")
kind_config_template_path=$(get_abs_filename "$configDir/kindconfig-template.yaml")
kind_config_file=$(get_abs_filename "$configDir/configkind-$cluster_name.yaml")
nyancat_argo_app_yaml=$(get_abs_filename "$configDir/nyancat-argo-app.yaml")
opencost_argo_app_yaml=$(get_abs_filename "$configDir/opencost-app.yaml")
argocd_ingress_yaml=$(get_abs_filename "$configDir/argocd-ingress.yaml")
cert_manager_yaml=$(get_abs_filename "$configDir/cert-manager.yaml")
kubeview_yaml=$(get_abs_filename "$configDir/kubeview.yaml")
trivy_app_yaml=$(get_abs_filename "$configDir/trivy-app.yaml")
metallb_app_yaml=$(get_abs_filename "$configDir/metallb-app.yaml")
kube_prometheus_stack_yaml=$(get_abs_filename "$configDir/kube_prometheus_stack.yaml")
cluster_info_file=$(get_abs_filename "$configDir/clusterinfo-$cluster_name.txt")
argocd_password=""

declare -a kindk8sversions=(
    "v1.32.0:kindest/node:v1.32.0@sha256:c48c62eac5da28cdadcf560d1d8616cfa6783b58f0d94cf63ad1bf49600cb027"
    "v1.31.4:kindest/node:v1.31.4@sha256:2cb39f7295fe7eafee0842b1052a599a4fb0f8bcf3f83d96c7f4864c357c6c30"
    "v1.30.8:kindest/node:v1.30.8@sha256:17cd608b3971338d9180b00776cb766c50d0a0b6b904ab4ff52fd3fc5c6369bf"
    "v1.29.12:kindest/node:v1.29.12@sha256:62c0672ba99a4afd7396512848d6fc382906b8f33349ae68fb1dbfe549f70dec"
    "v1.28.15:kindest/node:v1.28.15@sha256:a7c05c7ae043a0b8c818f5a06188bc2c4098f6cb59ca7d1856df00375d839251"
    "v1.27.16:kindest/node:v1.27.16@sha256:2d21a61643eafc439905e18705b8186f3296384750a835ad7a005dceb9546d20"
    "v1.26.15:kindest/node:v1.26.15@sha256:c79602a44b4056d7e48dc20f7504350f1e87530fe953428b792def00bc1076dd"
    "v1.25.16:kindest/node:v1.25.16@sha256:6110314339b3b44d10da7d27881849a87e092124afab5956f2e10ecdb463b025"
)

firstk8sversion="${kindk8sversions[0]}"
IFS=':' read -r k8s_version kind_image <<< "$firstk8sversion"
kindk8simage=$kind_image
kindk8sversion=$k8s_version

kindk8spossibilities=""
for version in "${kindk8sversions[@]}"; do
    IFS=':' read -r k8s_version kind_image <<< "$version"
    kindk8spossibilities="$kindk8spossibilities $k8s_version,"
done

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

    echo -e "$clear"
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
    echo "  install-nginx-kind        alias: ink     Install Nginx Ingress Controller for kind to current cluster"    
    echo ""
    echo "Helm:"
    echo "  install-helm-argocd       alias: iha     Install ArgoCD with helm to current cluster"
    echo "  install-helm-metallb      alias: ihm     Install Metallb ArgoCD application"
    echo "  install-helm-trivy        alias: iht     Install Trivy Operator ArgoCD application"
    echo ""
    echo "ArgoCD Applications:"
    echo "  install-app-nyancat       alias: iac     Install Nyan-cat ArgoCD application"
    echo "  install-app-certmanager   alias: iacm    Install Cert-manager ArgoCD application"
    echo "  install-app-prometheus    alias: iap     Install Kube-prometheus-stack ArgoCD application"
    echo "  install-app-kubeview      alias: iakv    Install Kubeview ArgoCD application"
    echo "  install-app-opencost      alias: iaoc    Install OpenCost ArgoCD application"
    echo "  install-app-metallb       alias: iam     Install Metallb ArgoCD application"
    echo "  install-app-trivy         alias: iat     Install Trivy Operator ArgoCD application"
    
    echo ""
    echo "dependencies: docker, kind, kubectl, jq, base64 and helm"
    echo ""
    now=$(date)
    printf "Current date and time in Linux %s\n" "$now"
    echo ""
    echo -e "$clear"
}

clear

yellow='\033[0;33m'
clear='\033[0m'
blue='\033[0;34m'
red='\033[0;31m'

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

function prerequisites() {
  if ! command -v $1 1> /dev/null
  then
      echo -e "$red 🚨 $1 could not be found. Install it! 🚨"
      exit
  fi
}

function get_cluster_parameter() {
    prerequisites docker
    prerequisites kind
    prerequisites kubectl
    prerequisites helm
    prerequisites jq
    prerequisites base64

    echo -e "$clear"
    read -p "Enter the cluster name: (default: $cluster_name): " cluster_name_new
    if [ ! -z $cluster_name_new ]; then
        cluster_name=$cluster_name_new
    fi

    read -p "Enter number of control planes (default: 1): " controlplane_number_new 
    if [ ! -z $controlplane_number_new ]; then
        controlplane_number=$controlplane_number_new
    fi

    read -p "Enter number of workers (default: 0): " worker_number_new 
    if [ ! -z $worker_number_new ]; then
        worker_number=$worker_number_new
    fi

    read -p "Enter version of kubernetes version (available:$kindk8spossibilities default: $kindk8sversion): " selected_k8s_version 
    check_k8s_version=""
    selected_k8s_version=$(echo $selected_k8s_version | tr '[:upper:]' '[:lower:]')
    if [ ! -z $selected_k8s_version ]; then
        for version in "${kindk8sversions[@]}"; do
            IFS=';' read -r k8s_version kind_image <<< "$version"
            if [ "$selected_k8s_version" == "$k8s_version" ]; then
                kindk8simage=$kind_image
                kindk8sversion=$k8s_version
                check_k8s_version=$k8s_version
            fi
        done

        if [ -z $check_k8s_version ]; then
            echo -e "$red
            🛑 Kubernetes version $selected_k8s_version is not available. Next time, please select from the available versions: $kindk8spossibilities
            "
            die
        fi
    fi

    read -p "Install Nginx Controller for kind? (default: yes) (y/yes | n/no): " install_nginx_controller_new
    if [ "$install_nginx_controller_new" == "yes" ] || [ "$install_nginx_controller_new" == "y" ] || [ "$install_nginx_controller_new" == "" ]; then
        install_nginx_controller="yes"
    else
        install_nginx_controller="no"
    fi

    read -p "Install ArgoCD with helm? (default: yes) (y/yes | n/no): " install_argocd_new
    if [ "$install_argocd_new" == "yes" ] || [ "$install_argocd_new" == "y" ] || [ "$install_argocd_new" == "" ]; then
        install_argocd="yes"
    else
        install_argocd="no"
    fi

    kind_config_file=$(get_abs_filename "$configDir/configkind-$cluster_name.yaml")
    if [ -f "$kind_config_file" ]; then
        truncate -s 0 "$kind_config_file"
    fi

    echo "
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  ipFamily: dual
nodes:" >> $kind_config_file

    controlplane_port_http=$(find_free_port)
    controlplane_port_https=$(find_free_port)
    for i in $(seq 1 $controlplane_number); do
        echo "  - role: control-plane
    image: $kindk8simage
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: "$controlplane_port_http"
        protocol: TCP
      - containerPort: 443
        hostPort: "$controlplane_port_https"
        protocol: TCP" >> $kind_config_file
    
    local http=$(find_free_port)
    local https=$(find_free_port)

    controlplane_port_http=$http
    controlplane_port_https=$https
    
    done

    if [ $worker_number -gt 0 ]; then
        for i in $(seq 1 $worker_number); do
            echo "  - role: worker" >> $kind_config_file
            echo "    image: $kindk8simage" >> $kind_config_file
        done
    fi

    echo -e "$yellow\n⏰ Creating Kind cluster with the following configuration"

    echo -en "$yellow\nCluster name:" 
    echo -en "$blue $cluster_name"

    echo -en "$yellow\nHow many controlplanes?:"
    echo -en "$blue $controlplane_number"

    echo -en "$yellow\nHow many workers?:"
    echo -en "$blue $worker_number"

    echo -en "$yellow\nWhich version of kubernetes?:"
    echo -en "$blue $kindk8sversion"

    echo -en "$yellow\nInstall Nginx ingress controller for kind?:"
    echo -en "$blue $install_nginx_controller"

    echo -en "$yellow\nInstall ArgoCD with helm?:"
    echo -en "$blue $install_argocd"

    cluster_info_file=$(get_abs_filename "$configDir/clusterinfo-$cluster_name.txt")

    if [ -f "$cluster_info_file" ]; then
        truncate -s 0 "$cluster_info_file"
    fi

    echo "
Cluster name: $cluster_name
Controlplane number: $controlplane_number
Worker number: $worker_number
Kubernetes version: $kindk8sversion
Install Nginx ingress controller: $install_nginx_controller
Install ArgoCD: $install_argocd
ArgoCD admin GUI portforwarding: kubectl port-forward -n argocd services/argocd-server 58080:443
ArgoCD admin GUI url: http://localhost:58080" >> $cluster_info_file

    echo ""
    echo -e "$yellow\nKind command about to be run:"
    echo -e "$blue\nkind cluster create $cluster_name --config "$kind_config_file""
    
    echo -e "$clear"
    read -p "Looks ok (n | no | y | yes)? " ok

    if [ "$ok" == "yes" ] ;then
            echo "Excellent  👌 "
            create_cluster
        elif [ "$ok" == "y" ]; then
            echo "Good  🤌"
            create_cluster
        else
            echo "🛑 Did not notice and confirmation, I need you to confirm with a yes or y 😀 ... quitting"
            exit 0
    fi
}

function install_helm_argocd(){
    echo -e "$yellow
    Installing ArgoCD
    "
    helm repo add argo https://argoproj.github.io/argo-helm
    (helm install argocd argo/argo-cd --namespace argocd --create-namespace|| 
    { 
        echo -e "$red 
        🛑 Could not install argocd into cluster  ...
        "
        die
    }) & spinner

    echo -e "$yellow
    ⏰ Waiting for ArgoCD to be ready
    "
    sleep 7
    (kubectl wait --namespace argocd --for=condition=ready pod --selector=app.kubernetes.io/name=argocd-server --timeout=90s|| 
    { 
        echo -e "$red 
        🛑 Could not install argocd into cluster  ...
        "
        die
    }) & spinner

    echo -e "$yellow
    ✅ Done installing ArgoCD"
}

function install_helm_metallb(){
    echo -e "$yellow
    Installing Metallb
    "
    helm repo add metallb https://metallb.github.io/metallb
    (helm install metallb metallb/metallb --namespace metallb --create-namespace|| 
    { 
        echo -e "$red 
        🛑 Could not install metallb into cluster  ...
        "
        die
    }) & spinner

    echo -e "$yellow
    ✅ Done installing Metallb"
}

function install_helm_trivy(){
    echo -e "$yellow
    Installing Trivy-operator
    "
    helm repo add aqua https://aquasecurity.github.io/helm-charts/
    (  helm install trivy-operator aqua/trivy-operator --namespace trivy --create-namespace|| 
    { 
        echo -e "$red 
        🛑 Could not install Trivy-operator into cluster  ...
        "
        die
    }) & spinner

    echo -e "$yellow
    ✅ Done installing Trivy-operator"
}

function install_nginx_controller_for_kind(){
    echo -e "$yellow
    Create Nginx Ingress Controller for kind
    "        
    (kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml|| 
    { 
        echo -e "$red 
        Could not install nginx controller in cluster ...
        "
        die
    }) & spinner

    echo -e "$yellow
    ⏰ Waiting for Nginx ingress controller for kind to be ready
    "
    sleep 7
    (kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s|| 
    { 
        echo -e "$red 
        🛑 Could not install nginx ingress controller into cluster  ...
        "
        die
    }) & spinner

    echo -e "$yellow
    ✅ Done installing Nginx Ingress Controller"
}

function create_cluster() {
    if [ -z $cluster_name ]  || [ $controlplane_number -lt 1 ] || [ $worker_number -lt 0 ]; then
        echo "Not all parameters good ... quitting"
        die
    fi

    echo -e "$yellow ⏰ Creating Kind cluster"
    echo -e "$clear"
    (kind create cluster --name "$cluster_name" --config "$kind_config_file" || 
    { 
        echo -e "$red 
        🛑 Could not create cluster ...
        "
        die
    }) & spinner

    if [ "$install_nginx_controller" == "yes" ]; then
        install_nginx_controller_for_kind
    fi

    if [ "$install_argocd" == "yes" ]; then
        install_helm_argocd
        argocd_password="$(kubectl get secrets -n argocd argocd-initial-admin-secret -o json | jq -r '.data.password' | base64 -d)"

        echo "ArgoCD:"
        echo "Username: admin"
        echo "ArgoCD password: $argocd_password" >> $cluster_info_file
    fi

    echo -e "$yellow
    ✅ Done creating kind cluster
    "

    if [ "$install_argocd" == "yes" ]; then

    echo -e "$yellow
    🚀 ArgoCD is ready to use
    Port forward the ArgoCD server to access the UI:
    "
    echo -e "$white
    https (self-signed certificate):
    kubectl port-forward -n argocd services/argocd-server 58080:443
    "
    
    echo -e "$yellow
    Open the ArgoCD UI in your browser: http://localhost:58080
    
    🔑  Argocd Username: admin
    🔑  Argocd Password: $argocd_password

    "
    fi

    echo -e "$yellow
    To see all kind clusters , type: $red kind get clusters
    "

    echo -e "$yellow
    To delete cluster, type: $red kind delete cluster --name $cluster_name
    "
    echo -e "$clear"

    get_kubeconfig kc $cluster_name

    if [ "$install_argocd" == "yes" ]; then
        install_nyancat=""
        read -p "Install Nyan-cat ArgoCD application? (default: yes) (y/yes | n/no): " install_nyancat_new
        if [ "$install_nyancat_new" == "yes" ] || [ "$install_nyancat_new" == "y" ] || [ "$install_nyancat_new" == "" ]; then
            install_nyancat="yes"
        else
            install_nyancat="no"
        fi

        if [ "$install_nyancat" == "yes" ]; then
            install_nyancat_application
        fi
    fi
}

function install_nyancat_application(){
    echo -e "$yellow
    Installing Nyan-cat ArgoCD application
    "
    (kubectl apply -f $nyancat_argo_app_yaml|| 
    { 
        echo -e "$red 
        🛑 Could not install Nyan-cat ArgoCD application into cluster  ...
        "
        die
    }) & spinner

    echo -e "$yellow
    ✅ Done installing Nyan-cat ArgoCD application
    "

    echo "Nyancat argocd application installed: yes" >> $cluster_info_file
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

function see_details_of_cluster() {
    echo -e "$yellow
    🚀 Cluster details
    "
    echo -e "$clear"
    kubectl cluster-info
    echo -e "$yellow
    🚀 Nodes
    "
    echo -e "$clear"
    kubectl get nodes
    echo -e "$yellow
    🚀 Pods
    "
    echo -e "$clear"
    kubectl get pods --all-namespaces
    echo -e "$yellow
    🚀 Services
    "
    echo -e "$clear"
    kubectl get services --all-namespaces
    echo -e "$yellow
    🚀 Ingresses
    "
    echo -e "$clear"
    kubectl get ingresses --all-namespaces
}

function details_for_cluster() {
    clusterName=${@: -1}

    if [[ "$#" -lt 2 ]]; then 
        echo "Missing name of cluster"; 
        exit 1
    fi

    if [[ "$#" -gt 2 ]]; then 
        echo "Too many arguments"; 
        exit 1
    fi

    clusters=$(kind get clusters)
    if ! echo "$clusters" | grep -q "$clusterName"; then
        echo "Cluster $clusterName not found"
        exit 1
    fi

    echo -e "$yellow\nCluster details for $clusterName"
    cat $cluster_info_file

    echo -e "$yellow\nKind configuration for $clusterName"

    cat $kind_config_file
}

function delete_cluster() {
    clusterName=${@: -1}

    if [[ "$#" -lt 2 ]]; then 
        echo "Missing name of cluster"; 
        exit 1
    fi

    if [[ "$#" -gt 2 ]]; then 
        echo "Too many arguments"; 
        exit 1
    fi

    read -p "Sure you want to delete?! (n | no | y | yes)? " ok

    if [ "$ok" == "yes" ] ;then
            echo -e "$yellow\nDeleting cluster ..."
        elif [ "$ok" == "y" ]; then
            echo -e "$yellow\nDeleting cluster ..."
        elif [ "$ok" == "n" ]; then
            echo -e "$red\nThat was a close one! Not deleting!"
            exit 0
        elif [ "$ok" == "no" ]; then
            echo -e "$red\nThat was a close one! Not deleting!"
            exit 0
        else
            echo "🛑 Did not notice and confirmation, I need you to confirm with a yes or y 😀 ... quitting"
            exit 0
    fi

    (kind delete cluster --name $clusterName|| 
    { 
        echo -e "$red 
        🛑 Could not delete cluster with name $clusterName
        "
        die
    }) & spinner

    echo -e "$yellow
    ✅ Done deleting cluster
    "
}

function list_clusters() {
    kind get clusters
}

function get_kubeconfig() {
    if [ "$#" -ne 2 ]; then
        echo "Error: This script requires exactly two arguments."
        echo "Usage: $0 <arg1> <arg2>"
        exit 1
    fi

    local clusterName=$2
    if [ -z "$clusterName" ]; then
        echo "Missing name of cluster"; 
        exit 1
    fi

    echo "$(kind get kubeconfig --name $clusterName)" > kubeconfig-$clusterName.config

    echo -e "$yellow\nKubeconfig saved to kubeconfig-$clusterName.config"
    echo -e "$clear"
    echo -e "$yellow\nTo use the kubeconfig, type: $red export KUBECONFIG=kubeconfig-$clusterName.config"
    echo -e ""
    echo -e "$yellow\nAnd then you can use $blue kubectl $yellow to interact with the cluster"
    echo -e ""
    echo -e "$yellow\nExample: $blue kubectl get nodes"
}

function install_cert_manager_application() {
    (kubectl apply -n argocd -f $cert_manager_yaml||
    { 
        echo -e "$red 
        🛑 Could not install cert-manager to cluster
        "
        die
    }) & spinner

    echo -e "$yellow
    ✅ Done installing cert-manager
    "
}

function install_kube_prometheus_stack_application() {
    (kubectl apply -n argocd -f $kube_prometheus_stack_yaml||
    { 
        echo -e "$red 
        🛑 Could not install kube-prometheus-stack to cluster
        "
        die
    }) & spinner

    echo -e "$yellow
    ✅ Done installing kube-prometheus-stack
    "

    echo -e "$yellow\nTo access the kube-prometheus-stack dashboard, type: $red kubectl port-forward -n prometheus services/prometheus-grafana 30000:80"
    echo -e "$yellow\nOpen the dashboard in your browser: http://localhost:30000"

    echo -e "$yellow\nUsername: admin"
    echo -e "$yellow\nPassword: prom-operator"
}

function install_kubeview_application() {
    (kubectl apply -n argocd -f $kubeview_yaml||
    { 
        echo -e "$red 
        🛑 Could not install kubeview to cluster
        "
        die
    }) & spinner

    echo -e "$yellow
    ✅ Done installing kubeview
    "

    echo -e "$yellow\nTo access the kube-prometheus-stack dashboard, type: $red kubectl port-forward -n kubeview pods/<the pod name> 59000:8000"
    echo -e "$yellow\nOpen the dashboard in your browser: http://localhost:59000"
}

function install_opencost_application() {
    echo -e "$yellow
    Installing OpenCost ArgoCD application
    "
    (kubectl apply -f $opencost_argo_app_yaml|| 
    { 
        echo -e "$red 
        🛑 Could not install OpenCost ArgoCD application into cluster  ...
        "
        die
    }) & spinner

    echo -e "$yellow
    ✅ Done installing OpenCost ArgoCD application
    "

    echo "OpenCost argocd application installed: yes" >> $cluster_info_file

    echo -e "$yellow\nTo access the OpenCost dashboard, type: $red kubectl port-forward --namespace opencost service/opencost 9003 9090"
    echo -e "$yellow\nOpen the dashboard in your browser: http://localhost:9090"
}

function install_metallb_application() {
    echo -e "$yellow
    Installing Metallb ArgoCD application
    "
    (kubectl apply -f $metallb_app_yaml|| 
    { 
        echo -e "$red 
        🛑 Could not install Metallb ArgoCD application into cluster  ...
        "
        die
    }) & spinner

    echo -e "$yellow
    ✅ Done installing Metallb ArgoCD application
    "

    echo "Metallb application installed: yes" >> $cluster_info_file
}

function install_trivy_application() {
    echo -e "$yellow
    Installing Trivy ArgoCD application
    "
    (kubectl apply -f $trivy_app_yaml|| 
    { 
        echo -e "$red 
        🛑 Could not install Trivy ArgoCD application into cluster  ...
        "
        die
    }) & spinner

    echo -e "$yellow
    ✅ Done installing Trivy ArgoCD application
    "

    echo "Trivy application installed: yes" >> $cluster_info_file
}

perform_action() {
    local action=$1

    case $action in
        help|h)
            print_logo
            print_help
            exit;;
        create|c)
            print_logo
            get_cluster_parameter
            exit;;
        details|dt)
            print_logo
            see_details_of_cluster
            exit;;
        info|i)
            print_logo
            details_for_cluster $*
            exit;;
        delete|d)
            print_logo
            delete_cluster $*
            exit;;
        list|ls)
            print_logo
            list_clusters $*
            exit;;
        kubeconfig|kc)
            get_kubeconfig $*
            exit;;
        
        install-nginx-kind|ink)
            print_logo
            install_nginx_controller_for_kind
            exit;;
        
        install-helm-argocd|iha)
            print_logo
            install_helm_argocd
            exit;;
        install-helm-metallb|iha)
            print_logo
            install_helm_metallb
            exit;;
        install-helm-trivy|iht)
            print_logo
            install_helm_trivy
            exit;;

        install-app-nyancat|iacat)
            print_logo
            install_nyancat_application
            exit;;
        install-app-certmanager|iacm)
            print_logo
            install_cert_manager_application
            exit;;
        install-app-prometheus|iap)
            print_logo
            install_kube_prometheus_stack_application
            exit;;
        install-app-kubeview|iakv)
            print_logo
            install_kubeview_application
            exit;;
        install-app-opencost|iaoc)
            print_logo
            install_opencost_application
            exit;;
        install-app-metallb|iam)
            print_logo
            install_metallb_application
            exit;;
        install-app-trivy|iat)
            print_logo
            install_trivy_application
            exit;;
        
        *) # Invalid option
            echo -e "$red
            Error: Invalid option
            $clear
            "
            exit;;
   esac
}

perform_action $*

print_logo
print_help