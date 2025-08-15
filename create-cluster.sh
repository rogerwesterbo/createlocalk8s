#!/bin/bash

for file in ./scripts/variables.sh ./scripts/core/utils.sh ./scripts/core/cluster.sh ./scripts/core/config.sh ./scripts/installers/helm.sh ./scripts/installers/apps.sh; do
    if [ -f "$file" ]; then
        source "$file"
    else
        echo "Error: Required file $file not found. Exiting."
        exit 1
    fi
done

# file variables
scriptDir=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
manifestDir=$(get_abs_filename "$scriptDir/configs/apps/manifests")
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
mongodb_operator_app_yaml=$(get_abs_filename "$manifestDir/mongodb-operator-app.yaml")
mongodb_instance_yaml=$(get_abs_filename "$manifestDir/mongodb-instance.yaml")
mongodb_instance_service_yaml=$(get_abs_filename "$manifestDir/mongodb-instance-service.yaml")
falco_app_yaml=$(get_abs_filename "$manifestDir/falco-app.yaml")
kube_prometheus_stack_yaml=$(get_abs_filename "$manifestDir/kube_prometheus_stack.yaml")
cnpg_app_yaml=$(get_abs_filename "$manifestDir/cnpg-app.yaml")
cnpg_cluster_app_yaml=$(get_abs_filename "$manifestDir/cnpg-cluster-app.yaml")
core_dns_yaml=$(get_abs_filename "$manifestDir/core-dns.yaml")
pgadmin_app_yaml=$(get_abs_filename "$manifestDir/pgadmin-app.yaml")
rook_ceph_operator_app_yaml=$(get_abs_filename "$manifestDir/rook-ceph-operator-app.yaml")
rook_ceph_cluster_app_yaml=$(get_abs_filename "$manifestDir/rook-ceph-cluster-app.yaml")
cluster_info_file=$(get_abs_filename "$clustersDir/clusterinfo-$cluster_name.txt")
crossplane_app_yaml=$(get_abs_filename "$manifestDir/crossplane-app.yaml")
nginx_controller_app_yaml=$(get_abs_filename "$manifestDir/nginx-controller-app.yaml")
minio_app_yaml=$(get_abs_filename "$manifestDir/minio-app.yaml")
nfs_app_yaml=$(get_abs_filename "$manifestDir/nfs-app.yaml")


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
