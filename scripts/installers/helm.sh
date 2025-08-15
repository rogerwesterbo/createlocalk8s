#!/bin/bash

# Generic Helm install helper
function helm_install_generic() {
    local name="$1"
    local repo_name="$2"
    local repo_url="$3"
    local chart="$4"
    local namespace="$5"
    local extra_args="$6"
    local post_wait_cmd="$7"
    local post_msg="$8"

    echo -e "$yellow Installing $name"
    helm repo add "$repo_name" "$repo_url"
    (helm upgrade --install "$name" "$repo_name/$chart" --namespace "$namespace" --create-namespace $extra_args || 
    { 
        echo -e "$red 🛑 Could not install $name into cluster ..."
        die
    }) & spinner

    if [ -n "$post_wait_cmd" ]; then
        echo -e "$yellow\n⏰ Waiting for $name to be ready"
        sleep 10
        ($post_wait_cmd || 
        { 
            echo -e "$red 🛑 $name is not ready ..."
            die
        }) & spinner
    fi

    echo -e "$yellow ✅ Done installing $name"
    if [ -n "$post_msg" ]; then
        echo -e "$yellow$post_msg"
    fi
}

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

function install_helm_argocd(){
    echo -e "$yellow Installing ArgoCD "
    helm repo add argo https://argoproj.github.io/argo-helm
    (helm install argocd argo/argo-cd --namespace argocd --create-namespace --set configs.params.server.insecure=true || 
    { 
        echo -e "$red 🛑 Could not install argocd into cluster ..."
        die
    }) & spinner

    echo -e "$yellow\nPatch ArgoCD to allow insecure server"
    (kubectl patch configmaps -n argocd argocd-cmd-params-cm --type merge -p '{"data": { "server.insecure": "true" }}' || 
    { 
        echo -e "$red 🛑 Could not install argocd into cluster ..."
        die
    }) & spinner

    echo -e "$yellow\nRestarting ArgoCD server"
    (kubectl -n argocd rollout restart deployment argocd-server || 
    { 
        echo -e "$red 🛑 Could not restart argocd server ..."
        die
    }) & spinner

    echo -e "$yellow\n⏰ Waiting for ArgoCD to be ready"
    sleep 10
    (kubectl wait deployment -n argocd argocd-server --for condition=Available=True --timeout=180s || 
    { 
        echo -e "$red 🛑 Could not install argocd into cluster ..."
        die
    }) & spinner

    echo -e "$yellow\nInstalling ArgoCd Ingress"
    (kubectl apply -f $argocd_ingress_yaml || 
    { 
        echo -e "$red 🛑 Could not install argocd ingress into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing ArgoCD"
}

function install_helm_metallb(){
    helm_install_generic \
        "metallb" \
        "metallb" \
        "https://metallb.github.io/metallb" \
        "metallb" \
        "metallb" \
        "" \
        "" \
        ""
}

function install_helm_trivy(){
    helm_install_generic \
        "trivy-operator" \
        "aqua" \
        "https://aquasecurity.github.io/helm-charts/" \
        "trivy-operator" \
        "trivy" \
        "" \
        "" \
        ""
}

function install_helm_falco(){
    echo -e "$yellow Installing Falco"
    helm repo add falcosecurity https://falcosecurity.github.io/charts

    (helm install falco falcosecurity/falco --namespace falco --create-namespace --set tty=true --set falcosidekick.enabled=true --set falcosidekick.webui.enabled=true --set falcosidekick.config.webhook.address=http://falco-talon:2803 || 
    { 
        echo -e "$red 🛑 Could not install Falco into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Falco"

    post_falco_installation
}

function install_helm_vault(){
    echo -e "$yellow Installing Hashicorp Vault with helm"
    
    helm repo add hashicorp https://helm.releases.hashicorp.com
    (helm install vault hashicorp/vault --namespace vault --create-namespace || 
    { 
        echo -e "$red 🛑 Could not install Hashicorp Vault into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Hashicorp Vault"

    unseal_vault

    show_vault_after_installation
}

function install_helm_mongodb_operator(){
    echo -e "$yellow Installing Mongodb with helm"
    
    helm repo add bitnami https://charts.bitnami.com/bitnami
    (helm install mongodb bitnami/mongodb --namespace mongodb --create-namespace --values "$manifestDir/mongodb-values.yaml" || 
    { 
        echo -e "$red 🛑 Could not install Mongodb into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Mongodb"

    echo -e "$yellow\n⏰ Waiting for Mongodb to be running"
    sleep 10
    (kubectl wait pods --for=condition=Ready --all -n mongodb --timeout=120s || 
    { 
        echo -e "$red 🛑 Mongodb is not running, and is not ready to use ..."
        die
    }) & spinner

    show_mongodb_after_installation
}

function install_helm_mongodb_instance(){
    echo -e "$yellow Installing Mongodb Instance with helm"
    
    helm repo add bitnami https://charts.bitnami.com/bitnami
    (helm install mongodb-instance bitnami/mongodb --namespace mongodb-instance --create-namespace --values "$manifestDir/mongodb-values.yaml" || 
    { 
        echo -e "$red 🛑 Could not install Mongodb Instance into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Mongodb Instance"

    echo -e "$yellow\n⏰ Waiting for Mongodb Instance to be running"
    sleep 10
    (kubectl wait pods --for=condition=Ready --all -n mongodb-instance --timeout=120s || 
    { 
        echo -e "$red 🛑 Mongodb Instance is not running, and is not ready to use ..."
        die
    }) & spinner

    show_mongodb_after_installation
}

function install_helm_postgres(){
    echo -e "$yellow Installing Cloud Native Postgres Operator with helm"
    
    helm repo add cnpg https://cloudnative-pg.github.io/charts
    (helm upgrade --install postgres-operator \
  --namespace postgres-operator \
  --create-namespace \
  cnpg/cloudnative-pg || 
    { 
        echo -e "$red 🛑 Could not install Postgres Operator into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Postgres Operator"

    echo -e "$yellow Installing Postgres Cluster with helm"
    
    helm repo add cnpg https://cloudnative-pg.github.io/charts
    (helm upgrade --install postgres-cluster \
  --namespace postgres-cluster \
  --create-namespace \
  cnpg/cluster --set name=postgres-cluster --set cluster.instances='3' --set cluster.storage.size=3Gi || 
    { 
        echo -e "$red 🛑 Could not install Postgres Cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Postgres Cluster"

    post_postgres_installation
}

function install_helm_pgadmin(){
    echo -e "$yellow Installing PgAdmin4 with helm"
    helm repo add runix https://helm.runix.net
    (helm install pgadmin runix/pgadmin4 --namespace pgadmin --create-namespace || 
    { 
        echo -e "$red 🛑 Could not install PgAdmin4 into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing PgAdmin4"

    post_pgadmin_install
}


function install_helm_rook_ceph_operator(){
    echo -e "$yellow Installing Rook Ceph Operator via helm"
    helm repo add rook-release https://charts.rook.io/release
    (helm install --create-namespace --namespace rook-ceph rook-ceph rook-release/rook-ceph || 
    { 
        echo -e "$red 🛑 Could not install Rook Ceph Operator into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Rook Ceph Operator"
}

function install_helm_rook_ceph_cluster(){
    echo -e "$yellow Installing Rook Ceph Cluster via helm"
    helm repo add rook-release https://charts.rook.io/release
    (helm install --create-namespace --namespace rook-ceph rook-ceph-cluster --set operatorNamespace=rook-ceph rook-release/rook-ceph-cluster || 
    { 
        echo -e "$red 🛑 Could not install Rook Ceph Cluster into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Rook Ceph Cluster"
}

function install_helm_crossplane(){
    echo -e "$yellow Installing Crossplane"
    
    helm repo add crossplane-stable https://charts.crossplane.io/stable
    ( helm install crossplane --namespace crossplane-system --create-namespace crossplane-stable/crossplane|| 
    { 
        echo -e "$red 🛑 Could not install Crossplane into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Crossplane"
}

function install_helm_nginx_controller(){
    echo -e "$yellow Installing Nginx Controller"
    
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    ( helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace|| 
    { 
        echo -e "$red 🛑 Could not install Nginx Controller into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Nginx Controller"
}