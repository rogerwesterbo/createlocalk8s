#!/bin/bash

declare -a kindk8sversions=(
    "v1.33.1:kindest/node:v1.33.1@sha256:050072256b9a903bd914c0b2866828150cb229cea0efe5892e2b644d5dd3b34f"
    "v1.32.5:kindest/node:v1.32.5@sha256:e3b2327e3a5ab8c76f5ece68936e4cafaa82edf58486b769727ab0b3b97a5b0d"
    "v1.31.9:kindest/node:v1.31.9@sha256:b94a3a6c06198d17f59cca8c6f486236fa05e2fb359cbd75dabbfc348a10b211"
    "v1.30.13:kindest/node:v1.30.13@sha256:397209b3d947d154f6641f2d0ce8d473732bd91c87d9575ade99049aa33cd648"
    "v1.29.14:kindest/node:v1.29.14@sha256:8703bd94ee24e51b778d5556ae310c6c0fa67d761fae6379c8e0bb480e6fea29"
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