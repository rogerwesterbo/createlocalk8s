#!/bin/bash

for file in ./bash/variables.sh ./bash/common.sh ./bash/helm.sh ./bash/argo-apps.sh ./bash/kind.sh; do
    if [ -f "$file" ]; then
        source "$file"
    else
        echo "Error: Required file $file not found. Exiting."
        exit 1
    fi
done

# file variables
scriptDir=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
manifestDir=$(get_abs_filename "$scriptDir/manifests")
clustersDir=$(get_abs_filename "$scriptDir/clusters")
kind_config_path=$(get_abs_filename "$manifestDir/kindconfig.yaml")
kind_config_template_path=$(get_abs_filename "$manifestDir/kindconfig-template.yaml")
kind_config_file=$(get_abs_filename "$clustersDir/configkind-$cluster_name.yaml")
nyancat_argo_app_yaml=$(get_abs_filename "$manifestDir/nyancat-argo-app.yaml")
opencost_argo_app_yaml=$(get_abs_filename "$manifestDir/opencost-app.yaml")
argocd_ingress_yaml=$(get_abs_filename "$manifestDir/argocd-ingress.yaml")
cert_manager_yaml=$(get_abs_filename "$manifestDir/cert-manager.yaml")
kubeview_yaml=$(get_abs_filename "$manifestDir/kubeview.yaml")
trivy_app_yaml=$(get_abs_filename "$manifestDir/trivy-app.yaml")
vault_app_yaml=$(get_abs_filename "$manifestDir/hashicorp-vault-app.yaml")
metallb_app_yaml=$(get_abs_filename "$manifestDir/metallb-app.yaml")
mongodb_app_yaml=$(get_abs_filename "$manifestDir/mongodb-app.yaml")
falco_app_yaml=$(get_abs_filename "$manifestDir/falco-app.yaml")
kube_prometheus_stack_yaml=$(get_abs_filename "$manifestDir/kube_prometheus_stack.yaml")
cnpg_app_yaml=$(get_abs_filename "$manifestDir/cnpg-app.yaml")
cnpg_cluster_app_yaml=$(get_abs_filename "$manifestDir/cnpg-cluster-app.yaml")
core_dns_yaml=$(get_abs_filename "$manifestDir/core-dns.yaml")
pgadmin_app_yaml=$(get_abs_filename "$manifestDir/pgadmin-app.yaml")
rook_ceph_operator_app_yaml=$(get_abs_filename "$manifestDir/rook-ceph-operator-app.yaml")
rook_ceph_cluster_app_yaml=$(get_abs_filename "$manifestDir/rook-ceph-cluster-app.yaml")
cluster_info_file=$(get_abs_filename "$clustersDir/clusterinfo-$cluster_name.txt")
openebs_app_yaml=$(get_abs_filename "$manifestDir/openebs-app.yaml")
crossplane_app_yaml=$(get_abs_filename "$manifestDir/crossplane-app.yaml")
nginx_controller_app_yaml=$(get_abs_filename "$manifestDir/nginx-controller-app.yaml")
minio_app_yaml=$(get_abs_filename "$manifestDir/minio-app.yaml")
nfs_app_yaml=$(get_abs_filename "$manifestDir/nfs-app.yaml")

clear

function get_cluster_parameter() {
    detect_os
    check_prerequisites

    if ! docker info > /dev/null 2>&1; then
        echo -e "$red This script uses docker, and it isn't running - please start docker and try again!"
        exit 1
    fi

    clusterName=${@: -1}
    if [[ "$#" -lt 2 ]]; then 
        echo -e "$clear"
        read -p "Enter the cluster name: (default: $cluster_name): " cluster_name_new
        if [ ! -z $cluster_name_new ]; then
            cluster_name=$cluster_name_new
        fi
    else
        cluster_name=$clusterName
    fi

    cluster_name=$(echo $cluster_name | tr '[:upper:]' '[:lower:]')

    if [[ "$#" -gt 2 ]]; then 
        echo -e  "$red Too many arguments"; 
        echo -e "$clear"
        echo -e "$yellow Use the following command to create a cluster: $blue ./create-cluster.sh create|c <cluster-name>"
        exit 1
    fi

    echo -e "Cluster name: $cluster_name"

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
            echo -e "$red 🛑 Kubernetes version $selected_k8s_version is not available. Next time, please select from the available versions: $kindk8spossibilities"
            die
        fi
    fi

    # read -p "Install Nginx Controller for kind? (default: yes) (y/yes | n/no): " install_nginx_controller_new
    # if [ "$install_nginx_controller_new" == "yes" ] || [ "$install_nginx_controller_new" == "y" ] || [ "$install_nginx_controller_new" == "" ]; then
    #     install_nginx_controller="yes"
    # else
    #     install_nginx_controller="no"
    # fi
    install_nginx_controller="yes"

    read -p "Install ArgoCD with helm? (default: yes) (y/yes | n/no): " install_argocd_new
    if [ "$install_argocd_new" == "yes" ] || [ "$install_argocd_new" == "y" ] || [ "$install_argocd_new" == "" ]; then
        install_argocd="yes"
    else
        install_argocd="no"
    fi

    kind_config_file=$(get_abs_filename "$clustersDir/configkind-$cluster_name.yaml")
    echo -e "$yellow\nKind config file: $kind_config_file"
    if [ -e "$kind_config_file" ] && [ -r "$kind_config_file" ] && [ -w "$kind_config_file" ]; then
        truncate -s 0 "$kind_config_file"
    fi

    if [ ! -f $kind_config_file ]; then 
        echo "kind config file not found, creating it: $kind_config_file"
        touch $kind_config_file; 
    fi

    controlplane_port_http=80
    controlplane_port_https=443

    if [[ "$(is_running_more_than_one_cluster)" == "yes" ]]; then
        echo -e "$yellow\n🚨 You are running more than one kind cluster at once."
        local http=$(find_free_port)
        local https=$(find_free_port)

        controlplane_port_http=$http
        controlplane_port_https=$https
    fi

    first_controlplane_port_http=$controlplane_port_http
    first_controlplane_port_https=$controlplane_port_https

    echo "
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  ipFamily: dual
nodes:" >> $kind_config_file

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

    echo -en "$yellow\nCluster http port:"
    echo -en "$blue $first_controlplane_port_http"
    
    echo -en "$yellow\nCluster https port:"
    echo -en "$blue $first_controlplane_port_https"

    cluster_info_file=$(get_abs_filename "$clustersDir/clusterinfo-$cluster_name.txt")
    if [ -e "$cluster_info_file" ] && [ -r "$cluster_info_file" ] && [ -w "$cluster_info_file" ]; then
        truncate -s 0 "$cluster_info_file"
    fi

    echo "
Cluster name: $cluster_name
Controlplane number: $controlplane_number
Worker number: $worker_number
Kubernetes version: $kindk8sversion
Cluster http port: $first_controlplane_port_http
Cluster https port: $first_controlplane_port_https
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

# Generic Helm install helper
function helm_install_generic() {
    local name="$1"
    local repo_name="$2"
    local repo_url="$3"
    local chart="$4"
    local namespace="$5"
    local extra_args="$6"
    local post_wait_cmd="$7"
    local post_msg="$8"

    echo -e "$yellow Installing $name"
    helm repo add "$repo_name" "$repo_url"
    (helm upgrade --install "$name" "$repo_name/$chart" --namespace "$namespace" --create-namespace $extra_args || 
    { 
        echo -e "$red 🛑 Could not install $name into cluster ..."
        die
    }) & spinner

    if [ -n "$post_wait_cmd" ]; then
        echo -e "$yellow\n⏰ Waiting for $name to be ready"
        sleep 10
        ($post_wait_cmd || 
        { 
            echo -e "$red 🛑 $name is not ready ..."
            die
        }) & spinner
    fi

    echo -e "$yellow ✅ Done installing $name"
    if [ -n "$post_msg" ]; then
        echo -e "$yellow$post_msg"
    fi
}

function install_helm_argocd(){
    echo -e "$yellow Installing ArgoCD "
    helm repo add argo https://argoproj.github.io/argo-helm
    (helm install argocd argo/argo-cd --namespace argocd --create-namespace --set configs.params.server.insecure=true || 
    { 
        echo -e "$red 🛑 Could not install argocd into cluster ..."
        die
    }) & spinner

    echo -e "$yellow\nPatch ArgoCD to allow insecure server"
    (kubectl patch configmaps -n argocd argocd-cmd-params-cm --type merge -p '{"data": { "server.insecure": "true" }}' || 
    { 
        echo -e "$red 🛑 Could not install argocd into cluster ..."
        die
    }) & spinner

    echo -e "$yellow\nRestarting ArgoCD server"
    (kubectl -n argocd rollout restart deployment argocd-server || 
    { 
        echo -e "$red 🛑 Could not restart argocd server ..."
        die
    }) & spinner

    echo -e "$yellow\n⏰ Waiting for ArgoCD to be ready"
    sleep 10
    (kubectl wait deployment -n argocd argocd-server --for condition=Available=True --timeout=180s || 
    { 
        echo -e "$red 🛑 Could not install argocd into cluster ..."
        die
    }) & spinner

    echo -e "$yellow\nInstalling ArgoCd Ingress"
    (kubectl apply -f $argocd_ingress_yaml || 
    { 
        echo -e "$red 🛑 Could not install argocd ingress into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing ArgoCD"
}

function install_helm_metallb(){
    helm_install_generic \
        "metallb" \
        "metallb" \
        "https://metallb.github.io/metallb" \
        "metallb" \
        "metallb" \
        "" \
        "" \
        ""
}

function install_helm_trivy(){
    helm_install_generic \
        "trivy-operator" \
        "aqua" \
        "https://aquasecurity.github.io/helm-charts/" \
        "trivy-operator" \
        "trivy" \
        "" \
        "" \
        ""
}

function install_helm_falco(){
    echo -e "$yellow Installing Falco"
    helm repo add falcosecurity https://falcosecurity.github.io/charts

    (helm install falco falcosecurity/falco --namespace falco --create-namespace --set tty=true --set falcosidekick.enabled=true --set falcosidekick.webui.enabled=true --set falcosidekick.config.webhook.address=http://falco-talon:2803 || 
    { 
        echo -e "$red 🛑 Could not install Falco into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Falco"

    post_falco_installation
}

function install_helm_vault(){
    echo -e "$yellow Installing Hashicorp Vault with helm"
    
    helm repo add hashicorp https://helm.releases.hashicorp.com
    (helm install vault hashicorp/vault --namespace vault --create-namespace || 
    { 
        echo -e "$red 🛑 Could not install Hashicorp Vault into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Hashicorp Vault"

    unseal_vault

    show_vault_after_installation
}

function install_helm_mongodb(){
    echo -e "$yellow Installing Mongodb with helm"
    
    helm repo add bitnami https://charts.bitnami.com/bitnami
    (helm install mongodb bitnami/mongodb --namespace mongodb --create-namespace --values "$manifestDir/mongodb-values.yaml" || 
    { 
        echo -e "$red 🛑 Could not install Mongodb into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Mongodb"

    echo -e "$yellow\n⏰ Waiting for Mongodb to be running"
    sleep 10
    (kubectl wait pods --for=condition=Ready --all -n mongodb --timeout=120s || 
    { 
        echo -e "$red 🛑 Mongodb is not running, and is not ready to use ..."
        die
    }) & spinner

    show_mongodb_after_installation
}

function install_helm_postgres(){
    echo -e "$yellow Installing Cloud Native Postgres Operator with helm"
    
    helm repo add cnpg https://cloudnative-pg.github.io/charts
    (helm upgrade --install postgres-operator \
  --namespace postgres-operator \
  --create-namespace \
  cnpg/cloudnative-pg || 
    { 
        echo -e "$red 🛑 Could not install Postgres Operator into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Postgres Operator"

    echo -e "$yellow Installing Postgres Cluster with helm"
    
    helm repo add cnpg https://cloudnative-pg.github.io/charts
    (helm upgrade --install postgres-cluster \
  --namespace postgres-cluster \
  --create-namespace \
  cnpg/cluster --set name=postgres-cluster --set cluster.instances='3' --set cluster.storage.size=3Gi || 
    { 
        echo -e "$red 🛑 Could not install Postgres Cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Postgres Cluster"

    post_postgres_installation
}

function install_helm_pgadmin(){
    echo -e "$yellow Installing PgAdmin4 with helm"
    helm repo add runix https://helm.runix.net
    (helm install pgadmin runix/pgadmin4 --namespace pgadmin --create-namespace || 
    { 
        echo -e "$red 🛑 Could not install PgAdmin4 into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing PgAdmin4"

    post_pgadmin_install
}

function install_helm_openebs(){
    echo -e "$yellow Installing OpenEBS with helm"
    helm repo add openebs https://openebs.github.io/openebs

    (helm install openebs --namespace openebs openebs/openebs --create-namespace || 
    { 
        echo -e "$red 🛑 Could not install OpenEBS into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing OpenEBS"

    echo -e "$yellow\nTo see more documentation, go to https://docs.openebs.io/"
}

function install_helm_rook_ceph_operator(){
    echo -e "$yellow Installing Rook Ceph Operator via helm"
    helm repo add rook-release https://charts.rook.io/release
    (helm install --create-namespace --namespace rook-ceph rook-ceph rook-release/rook-ceph || 
    { 
        echo -e "$red 🛑 Could not install Rook Ceph Operator into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Rook Ceph Operator"
}

function install_helm_rook_ceph_cluster(){
    echo -e "$yellow Installing Rook Ceph Cluster via helm"
    helm repo add rook-release https://charts.rook.io/release
    (helm install --create-namespace --namespace rook-ceph rook-ceph-cluster --set operatorNamespace=rook-ceph rook-release/rook-ceph-cluster || 
    { 
        echo -e "$red 🛑 Could not install Rook Ceph Cluster into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Rook Ceph Cluster"
}

function install_vault_trivy(){
    echo -e "$yellow Installing Hashicorp Vault"
    
    (  helm install vault https://helm.releases.hashicorp.com/vault --namespace vault --create-namespace|| 
    { 
        echo -e "$red 🛑 Could not install Trivy-operator into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Trivy-operator"
}

function install_helm_crossplane(){
    echo -e "$yellow Installing Crossplane"
    
    helm repo add crossplane-stable https://charts.crossplane.io/stable
    ( helm install crossplane --namespace crossplane-system --create-namespace crossplane-stable/crossplane|| 
    { 
        echo -e "$red 🛑 Could not install Crossplane into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Crossplane"
}

function install_helm_nginx_controller(){
    echo -e "$yellow Installing Nginx Controller"
    
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    ( helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace|| 
    { 
        echo -e "$red 🛑 Could not install Nginx Controller into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Nginx Controller"
}

function install_nginx_controller_for_kind(){
    echo -e "$yellow Create Nginx Ingress Controller for kind"
    (kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml|| 
    { 
        echo -e "$red 🛑 Could not install nginx controller in cluster ..."
        die
    }) & spinner

    echo -e "$yellow\n⏰ Waiting for Nginx ingress controller for kind to be ready"
    sleep 10
    (kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s || 
    { 
        echo -e "$red 🛑 Could not install nginx ingress controller into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Nginx Ingress Controller"
}

function modify_coredns() {
    echo -e "$yellow\nSetting up CoreDNS"
    (kubectl apply -f "$core_dns_yaml" || 
    { 
        echo -e "$red 🛑 Could not setup CoreDNS ..."
        die
    }) & spinner

    echo -e "$yellow\nRestarting CoreDNS"
    (kubectl -n kube-system rollout restart deployment/coredns || 
    { 
        echo -e "$red 🛑 Could not restart CoreDNS ..."
        die
    }) & spinner

    echo -e "$yellow\n⏰ Waiting for CoreDNS"
    (kubectl -n kube-system rollout status --timeout 5m deployment/coredns || 
    { 
        echo -e "$red 🛑 Something went wrong waiting for CoreDNS ..."
        die
    }) & spinner
}

function create_cluster() {
    if [ -z $cluster_name ]  || [ $controlplane_number -lt 1 ] || [ $worker_number -lt 0 ]; then
        echo "Not all parameters good ... quitting"
        die
    fi

    echo -e "$yellow\n⏰ Creating Kind cluster"
    echo -e "$clear"
    (kind create cluster --name "$cluster_name" --config "$kind_config_file" || 
    { 
        echo -e "$red 🛑 Could not create cluster ..."
        die
    }) & spinner

    modify_coredns

    #if [ "$install_nginx_controller" == "yes" ]; then
        install_nginx_controller_for_kind
    #fi

    if [ "$install_argocd" == "yes" ]; then
        install_helm_argocd
        argocd_password="$(kubectl get secrets -n argocd argocd-initial-admin-secret -o json | jq -r '.data.password' | base64 -d)"

        echo "ArgoCD password: $argocd_password" >> $cluster_info_file
    fi

    echo -e "$yellow ✅ Done creating kind cluster"

    if [ "$install_argocd" == "yes" ]; then
    echo -e "$yellow 🚀 ArgoCD is ready to use"
    
    if [[ "$(is_running_more_than_one_cluster)" == "yes" ]]; then
    echo -e "$yellow\nOpen the ArgoCD UI in your browser: http://argocd.localtest.me:$first_controlplane_port_http"
    else
    echo -e "$yellow\nOpen the ArgoCD UI in your browser: http://argocd.localtest.me"
    fi
    
    echo -e "$yellow\n 🔑 Argocd Username:$blue admin"
    echo -e "$yellow 🔑 Argocd Password:$blue $argocd_password"
    fi

    if [[ "$(is_running_more_than_one_cluster)" == "yes" ]]; then
    echo -e "$yellow\n 🚀 Cluster default ports have been changed "
    echo -e "$yellow Cluster http port: $first_controlplane_port_http"
    echo -e "$yellow Cluster https port: $first_controlplane_port_https"

    echo -e "$yellow\n To access a application add the controlplane port to the application as follows:"
    echo -e "$yellow http://<application>.localtest.me:<controlplane http port>"
    echo -e "$yellow Example: http://nyancat.localtest.me:$first_controlplane_port_http"
    fi

    echo -e "$yellow\n To see all kind clusters , type: $red kind get clusters"
    echo -e "$yellow To delete cluster, type: $red kind delete cluster --name $cluster_name"
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
    echo -e "$yellow Installing Nyan-cat ArgoCD application"
    (kubectl apply -f $nyancat_argo_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Nyan-cat ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Nyan-cat ArgoCD application"
    echo -e "$yellow ⏰ Waiting for Nyancat ArgoCD application to be ready"
    sleep 10
    (kubectl wait --namespace nyan-cat --for=condition=ready pod --selector=app.kubernetes.io/name=nyan-cat --timeout=90s || 
    { 
        echo -e "$red 
        🛑 Could not install Nyan-cat ArgoCD application into cluster  ...
        "
        die
    }) & spinner

    echo "Nyancat argocd application installed: yes" >> $cluster_info_file

    echo -e "$yellow To access the Nyancat application:"
    if [[ $(is_running_more_than_one_cluster) == "yes" ]]; then
        echo -e "$yellow Open the following URL in your browser:$blue http://nyancat.localtest.me:<cluster http port>"
        echo -e "$yellow Find the cluster http port in file: $cluster_info_file)"
    else
        echo -e "$yellow Open the following URL in your browser:$blue http://nyancat.localtest.me"
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

function detect_arch() {
    local host_arch

    case "$(uname -m)" in
      x86_64*)
        host_arch=amd64
        ;;
      i?86_64*)
        host_arch=amd64
        ;;
      amd64*)
        host_arch=amd64
        ;;
      aarch64*)
        host_arch=arm64
        ;;
      arm64*)
        host_arch=arm64
        ;;
      arm*)
        host_arch=arm
        ;;
      i?86*)
        host_arch=x86
        ;;
      s390x*)
        host_arch=s390x
        ;;
      ppc64le*)
        host_arch=ppc64le
        ;;
      *)
        echo "Unsupported host arch. Must be x86_64, 386, arm, arm64, s390x or ppc64le." >&2
        exit 1
        ;;
    esac

  if [[ -z "${host_arch}" ]]; then
    return
  fi
  echo -n "${host_arch}"
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
  #echo -n "${host_os}"
}

function detect_binary() {
    host_arch=$(detect_arch)
    host_os=$(detect_os)

    GO_OUT="${KUBE_ROOT}/_output/local/bin/${host_os}/${host_arch}"
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

    clusterName=$(echo $clusterName | tr '[:upper:]' '[:lower:]')

    echo -e "$yellow\nDeleting cluster $clusterName"
    read -p "Sure you want to delete ?! (n | no | y | yes)? " ok

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
        echo -e "$red 🛑 Could not delete cluster with name $clusterName"
        die
    }) & spinner

    echo -e "$yellow ✅ Done deleting cluster"
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

    echo "$(kind get kubeconfig --name $clusterName)" > $clustersDir/kubeconfig-$clusterName.config

    echo -e "$yellow Kubeconfig saved to $clustersDir/kubeconfig-$clusterName.config"
    echo -e "$yellow To use the kubeconfig, type:$red export KUBECONFIG=$clustersDir/kubeconfig-$clusterName.config"
    echo -e "$yellow And then you can use $blue kubectl $yellow to interact with the cluster"
    echo -e "$yellow Example: $blue kubectl get nodes"
    echo ""
}

function install_cert_manager_application() {
    (kubectl apply -n argocd -f $cert_manager_yaml||
    { 
        echo -e "$red 🛑 Could not install cert-manager to cluster"
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing cert-manager"
}

function install_kube_prometheus_stack_application() {
    (kubectl apply -n argocd -f $kube_prometheus_stack_yaml||
    { 
        echo -e "$red 🛑 Could not install kube-prometheus-stack to cluster"
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing kube-prometheus-stack"

    echo -e "$yellow To access the kube-prometheus-stack dashboard, type: $red kubectl port-forward -n prometheus services/prometheus-grafana 30000:80"
    echo -e "$yellow\n Open the dashboard in your browser: http://localhost:30000"

    echo -e "$yellow\nUsername: admin"
    echo -e "$yellow\nPassword: prom-operator"
}

function install_kubeview_application() {
    (kubectl apply -n argocd -f $kubeview_yaml||
    { 
        echo -e "$red 🛑 Could not install kubeview to cluster"
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing kubeview"
    echo -e "$yellow\nTo access the kube-prometheus-stack dashboard, type: $red kubectl port-forward -n kubeview pods/<the pod name> 59000:8000"
    echo -e "$yellow Open the dashboard in your browser: http://localhost:59000"
}

function install_opencost_application() {
    echo -e "$yellow Installing OpenCost ArgoCD application"
    (kubectl apply -f $opencost_argo_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install OpenCost ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing OpenCost ArgoCD application"

    echo "OpenCost argocd application installed: yes" >> $cluster_info_file

    echo -e "$yellow\nTo access the OpenCost dashboard, type: $red kubectl port-forward --namespace opencost service/opencost 9003 9090"
    echo -e "$yellow\nOpen the dashboard in your browser: http://localhost:9090"
}

function install_openebs_application() {
    echo -e "$yellow Installing OpenEBS ArgoCD application"
    (kubectl apply -f $openebs_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install OpenEBS ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing OpenEBS ArgoCD application"

    echo "OpenEBS argocd application installed: yes" >> $cluster_info_file

    echo -e "$yellow\nTo see more documentation, go to https://docs.openebs.io/"
}

function install_metallb_application() {
    echo -e "$yellow Installing Metallb ArgoCD application"
    (kubectl apply -f $metallb_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Metallb ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Metallb ArgoCD application"
    echo "Metallb application installed: yes" >> $cluster_info_file
}

function install_trivy_application() {
    echo -e "$yellow Installing Trivy ArgoCD application "
    (kubectl apply -f $trivy_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Trivy ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Trivy ArgoCD application "

    echo "Trivy application installed: yes" >> $cluster_info_file
}

function install_falco_application() {
    echo -e "$yellow Installing Falco ArgoCD application "
    (kubectl apply -f $falco_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Falco ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Falco ArgoCD application"

    echo "Falco application installed: yes" >> $cluster_info_file

    post_falco_installation
}

function install_vault_application() {
    echo -e "$yellow Installing Hashicorp Vault ArgoCD application"
    (kubectl apply -f $vault_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Vault ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Vault ArgoCD application "

    unseal_vault

    show_vault_after_installation
}

function install_postgres_application() {
    echo -e "$yellow Installing Postgres ArgoCD application"
    (kubectl apply -f $cnpg_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Cloud Native Postgres ArgoCD application into cluster  ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Cloud Native Postgres ArgoCD application"

    echo -e "$yellow\n⏰ Waiting for Cloud Native Postgres to be running"
    sleep 10
    (kubectl wait --namespace postgres-operator --for=condition=ready pod --selector=app.kubernetes.io/name=cloudnative-pg --timeout=120s || 
    { 
        echo -e "$red 🛑 Postgres Operator is not running, and is not ready to use ..."
        die
    }) & spinner
    echo -e "$yellow\nPostgres Operator is ready to use"

    (kubectl apply -f $cnpg_cluster_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Cloud Native Postgres Cluster ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Cloud Native Postgres Cluster ArgoCD application"
    sleep 10
    (kubectl wait pods --for=condition=Ready --all -n postgres-cluster --timeout=120s || 
    { 
        echo -e "$red 🛑 Postgres Cluster is not running, and is not ready to use ..."
        die
    }) & spinner
    echo -e "$yellow\nPostgres Cluster is ready to use"

    post_postgres_installation
}

function install_pgadmin_application() {
    echo -e "$yellow Installing PgAdmin4 ArgoCD application"
    (kubectl apply -f $pgadmin_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install PgAdmin4 ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing PgAdmin4 ArgoCD application"
    post_pgadmin_install
}

function install_mongodb_application() {
    echo -e "$yellow Installing Mongodb ArgoCD application"
    (kubectl apply -f $mongodb_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Mongodb ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Mongodb ArgoCD application"

    echo -e "$yellow\n⏰ Waiting for Mongodb to be running"
    sleep 10
    (kubectl wait pods --for=condition=Ready --all -n mongodb --timeout=120s || 
    { 
        echo -e "$red 🛑 Mongodb is not running, and is not ready to use ..."
        die
    }) & spinner

    echo -e "$yellow\nMongodb is ready to use"

    show_mongodb_after_installation
}

function install_rook_ceph_operator_application() {
    echo -e "$yellow Installing Rook Ceph Operator ArgoCD application"
    (kubectl apply -f $rook_ceph_operator_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Rook Ceph Operator ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Rook Ceph Operator ArgoCD application"
}

function install_rook_ceph_cluster_application() {
    echo -e "$yellow Installing Rook Ceph Cluster ArgoCD application"
    (kubectl apply -f $rook_ceph_cluster_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Rook Ceph Cluster ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Rook Ceph Cluster ArgoCD application"
}

function install_crossplane_application() {
    echo -e "$yellow Installing Crossplane ArgoCD application"
    (kubectl apply -f $crossplane_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Crossplane ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Crossplane ArgoCD application"
}

function install_nginx_controller_application() {
    echo -e "$yellow Installing Nginx Controller ArgoCD application"
    (kubectl apply -f $nginx_controller_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Nginx Controller ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Nginx Controller ArgoCD application"
}

function post_pgadmin_install() {
    echo -e "$yellow\n⏰ Waiting for Pgadmin4 to be running"
    sleep 10
    (kubectl wait pods --for=condition=Ready --all -n pgadmin --timeout=120s || 
    { 
        echo -e "$red 🛑 Falco is not running, and is not ready to use ..."
        die
    }) & spinner

    echo -e "$yellow
    PgAdmin4 is ready to use
    "
    echo -e "$yellow
    PgAdmin4 admin GUI portforwarding:$blue kubectl port-forward -n pgadmin services/pgadmin-pgadmin4 5050:80
    PgAdmin4 admin GUI url: http://localhost:5050
    "
    echo -e "$yellow
    PgAdmin4 username: chart@domain.com
    PgAdmin4 password: SuperSecret
    "

    echo -e "$yellow
    Get available services by typing$blue kubectl get services -A
    Use the ip to the service when connecting to the postgres instance 
    "
}

function show_vault_after_installation() {
    echo -e "$yellow\nVaut is ready to use"
    echo -e "$yellow\nTo access the Vault dashboard, type:$blue kubectl port-forward --namespace vault service/vault 8200:8200"
    echo -e "$yellow\nOpen the dashboard in your browser: http://localhost:8200"
    echo -e "$yellow\nToken to use: $(jq -cr '.root_token' vault-init.json)"
    echo -e ""
}

function post_postgres_installation() {    
    echo -e "$yellow\n Port forward to access the database:$blue kubectl port-forward -n postgres-cluster services/postgres-cluster-rw 5432:5432"
    echo -e "$yellow\n Use your favorite database client to connect to the database"
    echo -e "$yellow User: postgres"
    postgres_password=$(kubectl get secrets -n postgres-cluster postgres-cluster-superuser -o json | jq -r '.data.password' | base64 -d)
    echo -e "$yellow Password: $postgres_password"
    echo -e "$yellow\n Example:$blue pgcli -h localhost -U postgres -p 5432"
    echo -e ""
}

function post_falco_installation() {
    echo -e "$yellow\n ⏰ Waiting for Falco to be running"
    sleep 10
    (kubectl wait pods --for=condition=Ready --all -n falco --timeout=120s || 
    { 
        echo -e "$red 🛑 Falco is not running, and is not ready to use ..."
        die
    }) & spinner

    echo -e "$yellow\nFalco is ready to use"
    echo -e "$yellow\nTo access the Falco dashboard, type:$blue kubectl port-forward --namespace falco services/falco-falcosidekick-ui 2802:2802"
    echo -e "$yellow\nOpen the dashboard in your browser: http://localhost:2803"
    echo -e "$yellow\nDefault credentials: admin/admin"
    echo ""
    echo -e "$yellow\nTrigger an event to test Falco by executing: $blue kubectl exec -it -n falco pods/<a pod name> -- /bin/bash"
    echo -e "$yellow\nCheck the logs by executing:$blue kubectl logs -n falco -l app.kubernetes.io/name=falco"
    echo -e "$yellow\nOr check the dashboard at: http://localhost:2803"
}

function unseal_vault() {
    echo -e "$yellow\n⏰ Waiting for vault to be running"
    sleep 10
    (kubectl wait --namespace vault --for=condition=PodReadyToStartContainers pod/vault-0 --timeout=90s || 
    { 
        echo -e "$red 🛑 Could not install nginx ingress controller into cluster ..."
        die
    }) & spinner

    echo -e "$yellow\nUnsealing the vault"
    (kubectl exec -i -n vault vault-0 -- vault operator init -format=json > vault-init.json || 
    { 
        echo -e "$red 🛑 Could not install unseal the vault ..."
        die
    }) & spinner
    echo -e "$clear"

    echo -e "$yellow\nKeys to unseal the vault"
    jq -cr '.unseal_keys_b64[]' vault-init.json

    echo -e "$yellow\nRoot token"
    jq -cr '.root_token' vault-init.json

    echo -e "$yellow\n Unseal progress"
    keys=$(jq -cr '.unseal_keys_b64[]' vault-init.json)
    for i in $keys; do
        echo "\nUnsealing vault with key: $i"
        echo "kubectl exec -i -n vault vault-0 -- vault operator unseal $i"
        kubectl exec -i -n vault vault-0 -- vault operator unseal "$i"
    done
}

function show_mongodb_after_installation() {
    echo -e "$yellow\nMongodb is ready to use"
    echo -e "$yellow\nTo access the Mongodb dashboard, type:$blue kubectl port-forward --namespace mongodb service/mongodb 27017:27017"
    echo -e "$yellow\nUse mongosh to connect to the database"
    echo -e "$yellow\nExample:$blue mongosh mongodb://localhost:27017"
    echo -e "$yellow\nOr with credentials:$blue mongosh mongodb://root:SuperSecret@localhost:27017"
    echo -e "$yellow\nUsername: root"
    echo -e "$yellow\nPassword: SuperSecret"
    echo -e "$clear"
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
            get_cluster_parameter $*
            exit;;
        details|dt)
            see_details_of_cluster
            exit;;
        info|i)
            details_for_cluster $*
            exit;;
        delete|d)
            delete_cluster $*
            exit;;
        list|ls)
            list_clusters $*
            exit;;
        kubeconfig|kc)
            get_kubeconfig $*
            exit;;
        
        install-helm-argocd|iha)
            install_helm_argocd
            exit;;
        install-helm-metallb|ihm)
            install_helm_metallb
            exit;;
        install-helm-mongodb|ihmdb)
            install_helm_mongodb
            exit;;
        install-helm-trivy|iht)
            install_helm_trivy
            exit;;
        install-helm-vault|ihv)
            install_helm_vault
            exit;;
        install-helm-falco|ihf)
            install_helm_falco
            exit;;
        install-helm-postgres|ihpg)
            install_helm_postgres
            exit;;
        install-helm-pgadmin|ihpga)
            install_helm_pgadmin
            exit;;
        install-helm-rook_ceph_operator|ihrco)
            install_helm_rook_ceph_operator
            exit;;
        install-helm-rook_ceph_cluster|ihrcc)
            install_helm_rook_ceph_cluster
            exit;;
        install-helm-openebs|ihoe)
            install_helm_openebs
            exit;;
        install-helm-crossplane|ihcr)
            install_helm_crossplane
            exit;;
        install-helm-nginx|ihn)
            install_helm_nginx_controller
            exit;;
        install-helm-minio|ihmin)
            install_helm_minio
            exit;;
        install-helm-nfs|ihnfs)
            install_helm_nfs
            exit;;

        install-app-nyancat|iac)
            install_nyancat_application
            exit;;
        install-app-certmanager|iacm)
            install_cert_manager_application
            exit;;
        install-app-prometheus|iap)
            install_kube_prometheus_stack_application
            exit;;
        install-app-kubeview|iakv)
            install_kubeview_application
            exit;;
        install-app-opencost|iaoc)
            install_opencost_application
            exit;;
        install-app-openebs|iaoe)
            install_openebs_application
            exit;;
        install-app-metallb|iam)
            install_metallb_application
            exit;;
        install-app-mongodb|iamdb)
            install_mongodb_application
            exit;;
        install-app-falco|iaf)
            install_falco_application
            exit;;
        install-app-trivy|iat)
            install_trivy_application
            exit;;
        install-app-vault|iav)
            install_vault_application
            exit;;
        install-app-postgres|iapg)
            install_postgres_application
            exit;;
        install-app-pgadmin|iapga)
            install_pgadmin_application
            exit;;
        install-app-rook-ceph-operator|iarco)
            install_rook_ceph_operator_application
            exit;;
        install-app-rook-ceph-cluster|iarcc)
            install_rook_ceph_cluster_application
            exit;;
        install-app-crossplane|iacr)
            install_crossplane_application
            exit;;
        install-app-nginx|ian)
            install_nginx_controller_application
            exit;;
        install-app-minio|iamin)
            install_minio_application
            exit;;
        install-app-nfs|ianfs)
            install_nfs_application
            exit;;
        *) # Invalid option
            print_logo
            echo -e "$red
            Error: Invalid option
            $clear
            "
            exit;;
   esac
}

if [ "$#" -eq 0 ]; then
    detect_os
    print_logo
    print_help

    check_prerequisites

    exit
else
    detect_os
    perform_action $*
fi
