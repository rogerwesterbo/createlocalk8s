#!/bin/bash

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