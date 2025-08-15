#!/bin/bash

function print_logo() {
    echo -e "$blue"

    echo ""
    echo " ▄████▄   ██▀███  ▓█████ ▄▄▄     ▄▄▄█████▓▓█████     ▄████▄   ██▓     █    ██   ██████ ▄▄▄█████▓▓█████  ██▀███  ";
    echo "▒██▀ ▀█  ▓██ ▒ ██▒▓█   ▀▒████▄   ▓  ██▒ ▓▒▓█   ▀    ▒██▀ ▀█  ▓██▒     ██  ▓██▒▒██    ▒ ▓  ██▒ ▓▒▓█   ▀ ▓██ ▒ ██▒";
    echo "▒▓█    ▄ ▓██ ░▄█ ▒▒███  ▒██  ▀█▄ ▒ ▓██░ ▒░▒███      ▒▓█    ▄ ▒██░    ▓██  ▒██░░ ▓██▄   ▒ ▓██░ ▒░▒███   ▓██ ░▄█ ▒";
    echo "▒▓▓▄ ▄██▒▒██▀▀█▄  ▒▓█  ▄░██▄▄▄▄██░ ▓██▓ ░ ▒▓█  ▄    ▒▓▓▄ ▄██▒▒██░    ▓▓█  ░██░  ▒   ██▒░ ▓██▓ ░ ▒▓█  ▄ ▒██▀▀█▄  ";
    echo "▒ ▓███▀ ░░██▓ ▒██▒░▒████▒▓█   ▓██▒ ▒██▒ ░ ░▒████▒   ▒ ▓███▀ ░░██████▒▒▒█████▓ ▒██████▒▒  ▒██▒ ░ ░▒████▒░██▓ ▒██▒";
    echo "░ ░▒ ▒  ░░ ▒▓ ░▒▓░░░ ▒░ ░▒▒   ▓▒█░ ▒ ░░   ░░ ▒░ ░   ░ ░▒ ▒  ░░ ▒░▓  ░░▒▓▒ ▒ ▒ ▒ ▒▓▒ ▒ ░  ▒ ░░   ░░ ▒░ ░░ ▒▓ ░▒▓░";
    echo "  ░  ▒     ░▒ ░ ▒░ ░ ░  ░ ▒   ▒▒ ░   ░     ░ ░  ░     ░  ▒   ░ ░ ▒  ░░░▒░ ░ ░ ░ ░▒  ░ ░    ░     ░ ░  ░  ░▒ ░ ▒░";
    echo "░          ░░   ░    ░    ░   ▒    ░         ░      ░          ░ ░    ░░░ ░ ░ ░  ░  ░    ░         ░     ░░   ░ ";
    echo "░ ░         ░        ░  ░     ░  ░           ░  ░   ░ ░          ░  ░   ░           ░              ░  ░   ░     ";
    echo "░                                                   ░                                                           ";
    echo ""
}

function print_help() {
    echo -e "$yellow"
    echo "Kind specific:"    
    echo "  create                          alias: c       Create a local cluster with kind and docker"
    echo "  list                            alias: ls      Show kind clusters"
    echo "  details                         alias: dt      Show details for a cluster"
    echo "  kubeconfig                      alias: kc      Get kubeconfig for a cluster by name"
    echo "  delete                          alias: d       Delete a cluster by name"
    echo "  help                            alias: h       Print this Help"
    echo ""
    echo "Helm:"
    echo "  install-helm-argocd             alias: iha     Install ArgoCD with helm"
    echo "  install-helm-crossplane         alias: ihcr    Install Crossplane with helm"
    echo "  install-helm-ceph-operator      alias: ihrco   Install Rook Ceph Operator with helm"
    echo "  install-helm-ceph-cluster       alias: ihrcc   Install Rook Ceph Cluster with helm"
    echo "  install-helm-falco              alias: ihf     Install Falco with helm"
    echo "  install-helm-nfs                alias: ihnfs   Install NFS with helm"
    echo "  install-helm-nginx              alias: ihn     Install Nginx controller with helm"
    echo "  install-helm-metallb            alias: ihm     Install Metallb with helm"
    echo "  install-helm-minio              alias: ihmin   Install Minio with helm"
    echo "  install-helm-mongodb-operator   alias: ihmdb   Install Mongodb Operator with helm"
    echo "  install-helm-mongodb-instance   alias: ihmdbi  Install Mongodb Instance with helm"
    echo "  install-helm-postgres           alias: ihpg    Install Cloud Native Postgres Operator with helm"
    echo "  install-helm-pgadmin            alias: ihpa    Install PgAdmin4 with helm"
    echo "  install-helm-trivy              alias: iht     Install Trivy Operator with helm"
    echo "  install-helm-vault              alias: ihv     Install Vault with helm"
    echo ""
    echo "ArgoCD Applications:"
    echo "  install-app-ceph-operator       alias: iarco   Install Rook Ceph Operator ArgoCD application"
    echo "  install-app-ceph-cluster        alias: iarcc   Install Rook Ceph Cluster ArgoCD application"
    echo "  install-app-certmanager         alias: iacm    Install Cert-manager ArgoCD application"
    echo "  install-app-crossplane          alias: iacr    Install Crossplane ArgoCD application"
    echo "  install-app-falco               alias: iaf     Install Falco ArgoCD application"
    echo "  install-app-kubeview            alias: iakv    Install Kubeview ArgoCD application"
    echo "  install-app-nfs                 alias: ianfs   Install NFS ArgoCD application"
    echo "  install-app-nginx               alias: ian     Install Nginx Controller ArgoCD application"
    echo "  install-app-minio               alias: iamin   Install Minio ArgoCD application"
    echo "  install-app-mongodb-operator    alias: iamdb   Install Mongodb Operator ArgoCD application"
    echo "  install-app-mongodb-instance    alias: iamdbi  Install Mongodb Instance ArgoCD application"
    echo "  install-app-nyancat             alias: iac     Install Nyan-cat ArgoCD application"
    echo "  install-app-opencost            alias: iaoc    Install OpenCost ArgoCD application"
    echo "  install-app-postgres            alias: iapg    Install Cloud Native Postgres Operator ArgoCD application"
    echo "  install-app-pgadmin             alias: iapga   Install PgAdmin4 ArgoCD application"
    echo "  install-app-prometheus          alias: iap     Install Kube-prometheus-stack ArgoCD application"
    echo "  install-app-metallb             alias: iam     Install Metallb ArgoCD application"
    echo "  install-app-trivy               alias: iat     Install Trivy Operator ArgoCD application"
    echo "  install-app-vault               alias: iav     Install Hashicorp Vault ArgoCD application"
    echo ""
    echo "dependencies: docker, kind, kubectl, jq, base64 and helm"
    echo ""
    now=$(date)
    printf "Current date and time in Linux %s\n" "$now"
    echo ""
}

perform_action() {
    local action=$1

    case $action in
        help|h)
            print_logo
            print_help
            exit;;
        create|c)
            print_logo
            get_cluster_parameter $*
            exit;;
        details|dt)
            see_details_of_cluster
            exit;;
        info|i)
            details_for_cluster $*
            exit;;
        delete|d)
            delete_cluster $*
            exit;;
        list|ls)
            list_clusters $*
            exit;;
        kubeconfig|kc)
            get_kubeconfig $*
            exit;;
        
        install-helm-argocd|iha)
            install_helm_argocd
            exit;;
        install-helm-metallb|ihm)
            install_helm_metallb
            exit;;
        install-helm-mongodb-operator|ihmdb)
            install_helm_mongodb_operator
            exit;;
        install-helm-mongodb-instance|ihmdbi)
            install_helm_mongodb_instance
            exit;;
        install-helm-trivy|iht)
            install_helm_trivy
            exit;;
        install-helm-vault|ihv)
            install_helm_vault
            exit;;
        install-helm-falco|ihf)
            install_helm_falco
            exit;;
        install-helm-postgres|ihpg)
            install_helm_postgres
            exit;;
        install-helm-pgadmin|ihpa)
            install_helm_pgadmin
            exit;;
        install-helm-rook_ceph_operator|ihrco)
            install_helm_rook_ceph_operator
            exit;;
        install-helm-rook_ceph_cluster|ihrcc)
            install_helm_rook_ceph_cluster
            exit;;
        install-helm-crossplane|ihcr)
            install_helm_crossplane
            exit;;
        install-helm-nginx|ihn)
            install_helm_nginx_controller
            exit;;
        install-helm-minio|ihmin)
            install_helm_minio
            exit;;
        install-helm-nfs|ihnfs)
            install_helm_nfs
            exit;;

        install-app-nyancat|iac)
            install_nyancat_application
            exit;;
        install-app-certmanager|iacm)
            install_cert_manager_application
            exit;;
        install-app-prometheus|iap)
            install_kube_prometheus_stack_application
            exit;;
        install-app-kubeview|iakv)
            install_kubeview_application
            exit;;
        install-app-opencost|iaoc)
            install_opencost_application
            exit;;
        install-app-metallb|iam)
            install_metallb_application
            exit;;
        install-app-mongodb-operator|iamdb)
            install_mongodb_operator_application
            exit;;
        install-app-mongodb-instance|iamdbi)
            install_mongodb_instance
            exit;;
        install-app-falco|iaf)
            install_falco_application
            exit;;
        install-app-trivy|iat)
            install_trivy_application
            exit;;
        install-app-vault|iav)
            install_vault_application
            exit;;
        install-app-postgres|iapg)
            install_postgres_application
            exit;;
        install-app-pgadmin|iapga)
            install_pgadmin_application
            exit;;
        install-app-rook-ceph-operator|iarco)
            install_rook_ceph_operator_application
            exit;;
        install-app-rook-ceph-cluster|iarcc)
            install_rook_ceph_cluster_application
            exit;;
        install-app-crossplane|iacr)
            install_crossplane_application
            exit;;
        install-app-nginx|ian)
            install_nginx_controller_application
            exit;;
        install-app-minio|iamin)
            install_minio_application
            exit;;
        install-app-nfs|ianfs)
            install_nfs_application
            exit;;
        *) # Invalid option
            print_logo
            echo -e "$red
            Error: Invalid option
            $clear
            "
            exit;;
   esac
}