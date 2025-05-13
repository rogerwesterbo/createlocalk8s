#!/bin/bash

function install_minio_application() {
    echo -e "$yellow Installing Minio ArgoCD application "
    (kubectl apply -f $minio_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Minio ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Minio ArgoCD application"

    echo "Minio application installed: yes" >> $cluster_info_file

    post_minio_installation
}

function post_minio_installation() {
    echo -e "$yellow Post Minio installation steps"   
}

function install_nfs_application() {
    echo -e "$yellow Installing NFS Subdirectory External Provisioner ArgoCD application "
    (kubectl apply -f $nfs_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install NFS Subdirectory External Provisioner ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing NFS Subdirectory External Provisioner ArgoCD application"

    echo "NFS Subdirectory External Provisioner application installed: yes" >> $cluster_info_file
}