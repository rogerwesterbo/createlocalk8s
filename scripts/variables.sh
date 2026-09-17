#!/bin/bash

# global variables

kindk8sversions=(
    "v1.37.0:kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5"
    "v1.36.4:kindest/node:v1.36.4@sha256:099e049362a1526b2db71494e1947aae99bd16290d7c895f2b7ea312e3cbfaed"
    "v1.35.8:kindest/node:v1.35.8@sha256:07b2536e30b803ed61d1677a79df6115f798ce64c80f9e22f6ed45afd09323c0"
    "v1.34.11:kindest/node:v1.34.11@sha256:44e222ee2132dab25ff87301682f89eb82c7880ea3a1bf543bfe9708fd08d67d"
    "v1.33.12:kindest/node:v1.33.12@sha256:3f5c8443c620245e4d355cfe09e96a91ead32ceaa569d3f1ca9edf0cb2fe2ff4"
    "v1.32.11:kindest/node:v1.32.11@sha256:5fc52d52a7b9574015299724bd68f183702956aa4a2116ae75a63cb574b35af8"
    "v1.31.14:kindest/node:v1.31.14@sha256:6f86cf509dbb42767b6e79debc3f2c32e4ee01386f0489b3b2be24b0a55aac2b"
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

cluster_name="testcluster"
worker_number=0
controlplane_number=1
install_nginx_controller="yes"
install_argocd="yes"
argocd_password=""
custom_cni="default"

yellow='\033[0;33m'
clear='\033[0m'
blue='\033[0;34m'
red='\033[0;31m'
green='\033[0;32m'

# Talos Kubernetes versions - dynamically populated based on installed talosctl version
# See talos_populate_k8s_versions() in scripts/providers/talos-provider.sh
# Support matrix: https://docs.siderolabs.com/talos/v1.13/getting-started/support-matrix
talosk8sversions=()