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