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