#!/bin/bash

function install_helm_minio(){
    helm_install_generic \
        "minio-operator" \
        "minio" \
        "https://operator.min.io" \
        "minio-operator" \
        "minio" \
        "" \
        "" \
        ""
}

function install_helm_nfs(){
    helm_install_generic \
        "nfs-subdir-external-provisioner" \
        "nfs-subdir-external-provisioner" \
        "https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/" \
        "nfs-subdir-external-provisioner" \
        "nfs-subdir-external-provisioner" \
        "" \
        "" \
        ""
}