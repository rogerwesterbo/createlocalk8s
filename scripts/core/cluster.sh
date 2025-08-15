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

function get_cluster_parameter() {
    detect_os
    check_prerequisites
    check_docker_hub_login

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
            IFS=':' read -r k8s_version kind_image <<< "$version"
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
    labels:
        ingress-ready: \"true\"
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
            create_kind_cluster
        elif [ "$ok" == "y" ]; then
            echo "Good  🤌"
            create_kind_cluster
        else
            echo "🛑 Did not notice and confirmation, I need you to confirm with a yes or y 😀 ... quitting"
            exit 0
    fi
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

function create_kind_cluster() {
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

    install_nginx_controller_for_kind

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