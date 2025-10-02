#!/bin/bash

function is_running_more_than_one_cluster() {
    local clusters
    clusters=$(kind get clusters -q)

    return_statement="no"

    if [ "$clusters" == "No kind clusters found." ]; then
        return_statement="no"
    elif [ -z "$clusters" ]; then
        return_statement="no"
    elif [[ $(echo "$clusters" | wc -l) -eq 1 ]]; then
        return_statement="no"
    elif [[ $(echo "$clusters" | wc -l) -ge 2 ]]; then
        return_statement="yes"
    fi

    echo "$return_statement"
}

# Validate that a cluster exists, exit with error if not found
function validate_cluster_exists() {
    local clusterName="$1"
    
    if [ -z "$clusterName" ]; then
        echo -e "${red}\n🛑 Cluster name cannot be empty"
        exit 1
    fi
    
    local clusters
    clusters=$(kind get clusters 2>/dev/null)
    
    if ! echo "$clusters" | grep -q "^${clusterName}$"; then
        echo -e "${red}\n🛑 Cluster '${clusterName}' not found"
        echo -e "${yellow}\nAvailable clusters:"
        kind get clusters
        exit 1
    fi
}

# Validate that a cluster does NOT exist, exit with error if found
function validate_cluster_not_exists() {
    local clusterName="$1"
    
    if [ -z "$clusterName" ]; then
        echo -e "${red}\n🛑 Cluster name cannot be empty"
        exit 1
    fi
    
    local clusters
    clusters=$(kind get clusters 2>/dev/null)
    
    if echo "$clusters" | grep -q "^${clusterName}$"; then
        echo -e "${red}\n🛑 Cluster '${clusterName}' already exists"
        echo -e "${yellow}\nPlease choose a different name or delete the existing cluster first:"
        echo -e "  ${blue}./kl.sh delete ${clusterName}${clear}"
        exit 1
    fi
}

# Show error when cluster name parameter is missing
function show_missing_cluster_name_error() {
    local command_name="$1"
    local command_alias="$2"
    
    echo -e "${red}\n🛑 Missing cluster name parameter${clear}"
    echo -e "${yellow}\nUsage:${clear}"
    echo -e "  ${blue}./kl.sh ${command_name} <cluster-name>${clear}"
    
    if [ -n "$command_alias" ]; then
        echo -e "  ${blue}./kl.sh ${command_alias} <cluster-name>${clear}"
    fi
    
    echo -e "\n${yellow}Example:${clear}"
    echo -e "  ${blue}./kl.sh ${command_name} mycluster${clear}"
    
    echo -e "\n${yellow}To see available clusters, run:${clear}"
    echo -e "  ${blue}./kl.sh list${clear}"
    
    local clusters
    clusters=$(kind get clusters 2>/dev/null)
    
    if [ -n "$clusters" ] && [ "$clusters" != "No kind clusters found." ]; then
        echo -e "\n${yellow}Available clusters:${clear}"
        kind get clusters
    fi
    
    exit 1
}

check_kind_clusters() {
    local output
    if output=$(kind get clusters -q); then
        if [[ "$output" == "No kind clusters found." ]]; then
            echo "No kind clusters found."
            return 0
        elif [[ -z "$output" ]]; then
            echo "Cluster list is empty."
            return 0
        elif [[ $(echo "$output" | wc -l) -eq 1 ]]; then
            echo "Exactly one kind cluster found."
            return 1
        elif [[ $(echo "$output" | wc -l) -ge 1 ]]; then
            echo "One or more kind clusters found."
            return 1
        elif [[ $(echo "$output" | wc -l) -ge 2 ]]; then
            echo "More than one kind cluster found."
            return 1
        else
            echo "Unexpected output: $output"
            return 1
        fi
        return 0
    else
        return 0
    fi
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

function show_kubernetes_details() {
    if [[ "$#" -lt 1 ]]; then 
        show_missing_cluster_name_error "k8sdetails" "k8s"
    fi

    if [[ "$#" -gt 1 ]]; then 
        echo "Too many arguments"; 
        exit 1
    fi

    local clusterName="$1"
    
    # Validate cluster exists
    validate_cluster_exists "$clusterName"
    
    echo -e "$yellow\n🔄 Switching to cluster context: $blue$clusterName"
    kubectl config use-context "kind-$clusterName" 2>/dev/null || {
        echo -e "$red 🛑 Could not switch to cluster context"
        exit 1
    }
    echo -e "$clear"
    
    echo -e "$blue"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "                    📊 Kubernetes Cluster Details                              "
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo -e "$clear"
    
    see_details_of_cluster
    
    echo -e "$yellow
    🚀 Deployments
    "
    echo -e "$clear"
    kubectl get deployments --all-namespaces
    
    echo -e "$yellow
    🚀 StatefulSets
    "
    echo -e "$clear"
    kubectl get statefulsets --all-namespaces
    
    echo -e "$yellow
    🚀 DaemonSets
    "
    echo -e "$clear"
    kubectl get daemonsets --all-namespaces
    
    echo -e "$yellow
    🚀 ConfigMaps
    "
    echo -e "$clear"
    kubectl get configmaps --all-namespaces
    
    echo -e "$yellow
    🚀 Secrets
    "
    echo -e "$clear"
    kubectl get secrets --all-namespaces
    
    echo -e "$yellow
    🚀 Persistent Volumes
    "
    echo -e "$clear"
    kubectl get pv
    
    echo -e "$yellow
    🚀 Persistent Volume Claims
    "
    echo -e "$clear"
    kubectl get pvc --all-namespaces
    
    echo -e "$yellow
    🚀 Storage Classes
    "
    echo -e "$clear"
    kubectl get storageclass
    
    echo -e "$blue"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo -e "$clear"
}

function list_clusters() {
echo -e "$yellow 🚀 K8s local Clusters:"
echo -e "$clear"
kind get clusters
}

function get_kubeconfig() {
    if [ "$#" -lt 1 ]; then
        show_missing_cluster_name_error "kubeconfig" "kc"
    fi

    if [ "$#" -gt 1 ]; then
        echo "Too many arguments"
        exit 1
    fi

    local clusterName="$1"
    if [ -z "$clusterName" ]; then
        show_missing_cluster_name_error "kubeconfig" "kc"
    fi

    # Validate cluster exists
    validate_cluster_exists "$clusterName"

    echo "$(kind get kubeconfig --name "$clusterName")" > "$clustersDir/$clusterName-kube.config"

    echo -e "$yellow Kubeconfig saved to $clustersDir/$clusterName-kube.config"
    echo -e "$yellow To use the kubeconfig, type:$red export KUBECONFIG=$clustersDir/$clusterName-kube.config"
    echo -e "$yellow And then you can use $blue kubectl$yellow to interact with the cluster"
    echo -e "$yellow Example: $blue kubectl get nodes"
    echo ""
}

function delete_cluster() {
    if [[ "$#" -lt 1 ]]; then 
        show_missing_cluster_name_error "delete" "d"
    fi

    if [[ "$#" -gt 1 ]]; then 
        echo "Too many arguments"; 
        exit 1
    fi

    local clusterName="$1"
    clusterName=$(echo "$clusterName" | tr '[:upper:]' '[:lower:]')

    # Validate cluster exists
    validate_cluster_exists "$clusterName"

    echo -e "$yellow\nDeleting cluster $clusterName"
    read -p "Are you sure you want to delete? (n | no | y | yes)? " ok

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
            echo "🛑 Did not detect any confirmation, I need you to confirm with a yes or y 😀 ... quitting"
            exit 0
    fi

    (kind delete cluster --name "$clusterName" ||
    { 
        echo -e "$red 🛑 Could not delete cluster with name $clusterName"
        die
    }) & spinner

    echo -e "$yellow ✅ Done deleting cluster"
}

function details_for_cluster() {
    if [[ "$#" -lt 1 ]]; then 
        show_missing_cluster_name_error "details" "dt"
    fi

    if [[ "$#" -gt 1 ]]; then 
        echo "Too many arguments"; 
        exit 1
    fi

    local clusterName="$1"

    # Validate cluster exists
    validate_cluster_exists "$clusterName"

    # Build file paths using the provided cluster name
    local cluster_info_file_path
    local kind_config_file_path
    cluster_info_file_path=$(get_abs_filename "$clustersDir/$clusterName-clusterinfo.txt")
    kind_config_file_path=$(get_abs_filename "$clustersDir/$clusterName-config.yaml")

    echo -e "$yellow\nCluster details for $clusterName"
    
    if [ -f "$cluster_info_file_path" ]; then
        cat "$cluster_info_file_path"
    else
        echo -e "$red\nCluster info file not found: $cluster_info_file_path"
    fi

    echo -e "$yellow\nKind configuration for $clusterName"

    if [ -f "$kind_config_file_path" ]; then
        cat "$kind_config_file_path"
    else
        echo -e "$red\nKind config file not found: $kind_config_file_path"
    fi
}

function get_cluster_parameter() {
    detect_os
    check_prerequisites
    ensure_docker_running
    check_docker_hub_login

    if [[ "$#" -lt 1 ]]; then 
        echo -e "$clear"
        read -p "Enter the cluster name: (default: $cluster_name): " cluster_name_new
        if [ -n "$cluster_name_new" ]; then
            cluster_name=$cluster_name_new
            echo -e "$yellow ✅ Cluster name set to: $blue$cluster_name"
            echo -e "$clear"
        else
            echo -e "$yellow ✅ Using default cluster name: $blue$cluster_name"
            echo -e "$clear"
        fi
    else
        cluster_name="$1"
        echo -e "$yellow ✅ Cluster name: $blue$cluster_name"
        echo -e "$clear"
    fi

    cluster_name=$(echo "$cluster_name" | tr '[:upper:]' '[:lower:]')

    # Validate cluster name is unique
    validate_cluster_not_exists "$cluster_name"

    if [[ "$#" -gt 1 ]]; then 
        echo -e  "$red Too many arguments"; 
        echo -e "$clear"
        echo -e "$yellow Use the following command to create a cluster: $blue ./create-cluster.sh create|c <cluster-name>"
        exit 1
    fi

    read -p "Enter number of control planes (default: 1): " controlplane_number_new
    if [ -n "$controlplane_number_new" ]; then
        controlplane_number=$controlplane_number_new
        echo -e "$yellow ✅ Control planes set to: $blue$controlplane_number"
        echo -e "$clear"
    else
        echo -e "$yellow ✅ Using default control planes: $blue$controlplane_number"
        echo -e "$clear"
    fi

    read -p "Enter number of workers (default: 0): " worker_number_new
    if [ -n "$worker_number_new" ]; then
        worker_number=$worker_number_new
        echo -e "$yellow ✅ Workers set to: $blue$worker_number"
        echo -e "$clear"
    else
        echo -e "$yellow ✅ Using default workers: $blue$worker_number"
        echo -e "$clear"
    fi

    read -p "Enter version of Kubernetes (available:$kindk8spossibilities default: $kindk8sversion): " selected_k8s_version 
    check_k8s_version=""
    selected_k8s_version=$(echo "$selected_k8s_version" | tr '[:upper:]' '[:lower:]')
    if [ -n "$selected_k8s_version" ]; then
        for version in "${kindk8sversions[@]}"; do
            IFS=':' read -r k8s_version kind_image <<< "$version"
            if [ "$selected_k8s_version" == "$k8s_version" ]; then
                kindk8simage=$kind_image
                kindk8sversion=$k8s_version
                check_k8s_version=$k8s_version
            fi
        done

        if [ -z "$check_k8s_version" ]; then
            echo -e "$red 🛑 Kubernetes version $selected_k8s_version is not available. Next time, please select from the available versions: $kindk8spossibilities"
            die
        fi
        echo -e "$yellow ✅ Selected Kubernetes version: $blue$kindk8sversion"
        echo -e "$clear"
    else
        echo -e "$yellow ✅ Using default Kubernetes version: $blue$kindk8sversion"
        echo -e "$clear"
    fi

    install_nginx_controller="yes"

    read -p "Install ArgoCD with Helm? (default: yes) (y/yes | n/no): " install_argocd_new
    if [ "$install_argocd_new" == "yes" ] || [ "$install_argocd_new" == "y" ] || [ "$install_argocd_new" == "" ]; then
        install_argocd="yes"
        echo -e "$yellow ✅ ArgoCD will be installed"
        echo -e "$clear"
    else
        install_argocd="no"
        echo -e "$yellow ✅ ArgoCD will NOT be installed"
        echo -e "$clear"
    fi

    kind_config_file=$(get_abs_filename "$clustersDir/$cluster_name-config.yaml")
    echo -e "$yellow\nKind config file: $kind_config_file"
    if [ -e "$kind_config_file" ] && [ -r "$kind_config_file" ] && [ -w "$kind_config_file" ]; then
        truncate -s 0 "$kind_config_file"
    fi

    if [ ! -f "$kind_config_file" ]; then
        echo "Kind config file not found, creating it: $kind_config_file"
        touch "$kind_config_file"; 
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
        # Only the first control plane gets port mappings
        if [ $i -eq 1 ]; then
            echo "  - role: control-plane
    image: $kindk8simage
    labels:
        ingress-ready: \"true\"
    extraPortMappings:
      - containerPort: 80
        hostPort: "$controlplane_port_http"
        protocol: TCP
      - containerPort: 443
        hostPort: "$controlplane_port_https"
        protocol: TCP" >> $kind_config_file
        else
            # Additional control planes don't get host port mappings
            echo "  - role: control-plane
    image: $kindk8simage" >> $kind_config_file
        fi
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

    echo -en "$yellow\nHow many control planes?:"
    echo -en "$blue $controlplane_number"

    echo -en "$yellow\nHow many workers?:"
    echo -en "$blue $worker_number"

    echo -en "$yellow\nWhich version of Kubernetes?:"
    echo -en "$blue $kindk8sversion"

    echo -en "$yellow\nInstall Nginx ingress controller for kind?:"
    echo -en "$blue $install_nginx_controller"

    echo -en "$yellow\nInstall ArgoCD with Helm?:"
    echo -en "$blue $install_argocd"

    echo -en "$yellow\nCluster http port:"
    echo -en "$blue $first_controlplane_port_http"
    
    echo -en "$yellow\nCluster https port:"
    echo -en "$blue $first_controlplane_port_https"

    cluster_info_file=$(get_abs_filename "$clustersDir/$cluster_name-clusterinfo.txt")
    if [ -e "$cluster_info_file" ] && [ -r "$cluster_info_file" ] && [ -w "$cluster_info_file" ]; then
        truncate -s 0 "$cluster_info_file"
    fi

    echo "
Cluster name: $cluster_name
Control plane number: $controlplane_number
Worker number: $worker_number
Kubernetes version: $kindk8sversion
Cluster http port: $first_controlplane_port_http
Cluster https port: $first_controlplane_port_https
Install Nginx ingress controller: $install_nginx_controller
Install ArgoCD: $install_argocd
ArgoCD admin GUI port forwarding: kubectl port-forward -n argocd services/argocd-server 58080:443
ArgoCD admin GUI URL: http://localhost:58080" >> $cluster_info_file

    echo ""
    echo -e "$yellow\nKind command about to be run:"
    echo -e "$blue\nkind cluster create $cluster_name --config "$kind_config_file""
    
    echo -e "$clear"
    read -p "Looks ok (n | no | y | yes)? " ok

    if [ "$ok" == "yes" ] ;then
            echo "Excellent 👌"
            create_kind_cluster
        elif [ "$ok" == "y" ]; then
            echo "Good 🤌"
            create_kind_cluster
        else
            echo "🛑 Did not detect any confirmation, I need you to confirm with a yes or y 😀 ... quitting"
            exit 0
    fi
}

function install_nginx_controller_for_kind(){
    echo -e "$yellow Creating Nginx Ingress Controller for kind"
    (kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml||
    {
        echo -e "$red 🛑 Could not install Nginx controller in cluster ..."
        die
    }) & spinner

    echo -e "$yellow\n⏰ Patching Nginx controller to run on control-plane node"
    (kubectl patch deployment -n ingress-nginx ingress-nginx-controller -p '{"spec":{"template":{"spec":{"nodeSelector":{"ingress-ready":"true"}}}}}' ||
    {
        echo -e "$red 🛑 Could not patch Nginx controller ..."
        die
    }) & spinner

    echo -e "$yellow\n⏰ Waiting for Nginx ingress controller for kind to be ready"
    sleep 10
    (kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s ||
    {
        echo -e "$red 🛑 Could not install Nginx ingress controller into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Nginx Ingress Controller"
}

function create_kind_cluster() {
    if [ -z "$cluster_name" ] || [ "$controlplane_number" -lt 1 ] || [ "$worker_number" -lt 0 ]; then
        echo "Not all parameters are valid ... quitting"
        die
    fi

    # Double-check cluster doesn't exist before creating
    validate_cluster_not_exists "$cluster_name"

    echo -e "$yellow\n⏰ Creating Kind cluster"
    echo -e "$clear"
    (kind create cluster --name "$cluster_name" --config "$kind_config_file" || 
    { 
        echo -e "$red 🛑 Could not create cluster ..."
        die
    }) & spinner

    # Ensure kubectl is using the correct context for the newly created cluster
    echo -e "$yellow\n🔄 Switching to cluster context: kind-$cluster_name"
    kubectl config use-context "kind-$cluster_name" 2>/dev/null || {
        echo -e "$red 🛑 Could not switch to cluster context"
        die
    }
    
    # Verify cluster is ready
    echo -e "$yellow\n⏰ Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=60s || {
        echo -e "$red 🛑 Cluster nodes not ready in time"
        die
    }

    install_nginx_controller_for_kind

    if [ "$install_argocd" == "yes" ]; then
        install_helm_argocd
        argocd_password="$(kubectl get secrets -n argocd argocd-initial-admin-secret -o json | jq -r '.data.password' | base64 -d)"

        echo "ArgoCD password: $argocd_password" >> "$cluster_info_file"
    fi

    echo -e "$yellow ✅ Done creating kind cluster"

    if [ "$install_argocd" == "yes" ]; then
    echo -e "$yellow 🚀 ArgoCD is ready to use"
    
    if [[ "$(is_running_more_than_one_cluster)" == "yes" ]]; then
    echo -e "$yellow\nOpen the ArgoCD UI in your browser: http://argocd.localtest.me:$first_controlplane_port_http"
    else
    echo -e "$yellow\nOpen the ArgoCD UI in your browser: http://argocd.localtest.me"
    fi
    
    echo -e "$yellow\n 🔑 ArgoCD Username:$blue admin"
    echo -e "$yellow 🔑 ArgoCD Password:$blue $argocd_password"
    fi

    if [[ "$(is_running_more_than_one_cluster)" == "yes" ]]; then
    echo -e "$yellow\n 🚀 Cluster default ports have been changed"
    echo -e "$yellow Cluster http port: $first_controlplane_port_http"
    echo -e "$yellow Cluster https port: $first_controlplane_port_https"

    echo -e "$yellow\n To access an application add the control plane port to the application as follows:"
    echo -e "$yellow http://<application>.localtest.me:<control plane http port>"
    echo -e "$yellow Example: http://nyancat.localtest.me:$first_controlplane_port_http"
    fi

    echo -e "$yellow\n To see all kind clusters, type: $red kind get clusters"
    echo -e "$yellow To delete cluster, type: $red kind delete cluster --name $cluster_name"
    echo -e "$clear"

    get_kubeconfig "$cluster_name"

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