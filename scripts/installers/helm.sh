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

# Determine OpenBao values file location if not injected by the caller
if [ -z "${openbao_values_yaml:-}" ]; then
    helm_script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    openbao_values_yaml="$helm_script_root/configs/apps/values/openbao-values.yaml"
fi

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

function install_helm_local_path_provisioner(){
    echo -e "$yellow Installing Local Path Provisioner"
    
    # Install using OCI helm chart from GitHub Container Registry
    # Alternative (raw manifest): kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.32/deploy/local-path-storage.yaml
    (helm upgrade --install local-path-provisioner \
        oci://ghcr.io/rancher/local-path-provisioner/charts/local-path-provisioner \
        --version 0.0.32 \
        --namespace local-path-storage \
        --create-namespace \
        --set storageClass.defaultClass=true || { 
        echo -e "$red 🛑 Could not install Local Path Provisioner into cluster ..."; 
        die 
    }) & spinner

    echo -e "$yellow\n⏰ Waiting for Local Path Provisioner to be ready"
    sleep 10
    (kubectl wait deployment -n local-path-storage local-path-provisioner --for condition=Available=True --timeout=120s || { 
        echo -e "$red 🛑 Local Path Provisioner is not ready ..."; 
        die 
    }) & spinner

    echo -e "$yellow ✅ Done installing Local Path Provisioner"
    echo -e "$yellow\nLocal Path Provisioner is ready to use"
    echo -e "$yellow\nStorageClass 'local-path' is available for PVCs"
    echo -e "$yellow\nExample PVC:$blue"
    echo -e "  apiVersion: v1"
    echo -e "  kind: PersistentVolumeClaim"
    echo -e "  metadata:"
    echo -e "    name: local-path-pvc"
    echo -e "  spec:"
    echo -e "    accessModes:"
    echo -e "      - ReadWriteOnce"
    echo -e "    storageClassName: local-path"
    echo -e "    resources:"
    echo -e "      requests:"
    echo -e "        storage: 1Gi"
    echo -e "$yellow\nCheck storage class:$blue kubectl get storageclass"
}

function install_helm_valkey(){
    echo -e "$yellow Installing Valkey"
    helm repo add valkey https://valkey.io/valkey-helm/
    (helm upgrade --install valkey valkey/valkey \
        --namespace valkey \
        --create-namespace || { 
        echo -e "$red 🛑 Could not install Valkey into cluster ..."; 
        die 
    }) & spinner

    echo -e "$yellow\n⏰ Waiting for Valkey to be ready"
    sleep 10
    (kubectl wait pods --for=condition=Ready --all -n valkey --timeout=180s || { 
        echo -e "$red 🛑 Valkey is not ready ..."; 
        die 
    }) & spinner

    echo -e "$yellow ✅ Done installing Valkey"
    echo -e "$yellow\nValkey is ready to use"
    echo -e "$yellow\nTo access Valkey CLI: $blue kubectl exec -it -n valkey statefulset/valkey-master -- valkey-cli"
    echo -e "$yellow\nTo access Valkey locally (port-forward):$blue kubectl port-forward -n valkey svc/valkey-master 6381:6379"
    echo -e "$yellow\nConnect using valkey-cli:$blue valkey-cli -h localhost -p 6381"
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

function install_helm_openbao(){
    echo -e "$yellow Installing OpenBao"

    helm repo add openbao https://openbao.github.io/openbao-helm
    (helm upgrade --install openbao openbao/openbao \
        --namespace openbao \
        --create-namespace \
        --values "$openbao_values_yaml" || {
        echo -e "$red 🛑 Could not install OpenBao into cluster ...";
        die
    }) & spinner

    echo -e "$yellow\n⏰ Waiting for OpenBao to be ready"
    sleep 10
    (kubectl rollout status statefulset/openbao -n openbao --timeout=300s || {
        echo -e "$red 🛑 OpenBao is not ready ...";
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing OpenBao"
    echo -e "$yellow\nOpenBao runs in dev mode for quick local experiments"
    echo -e "$yellow Root token:$blue openbao-root"
    echo -e "$yellow Port-forward:$blue kubectl port-forward -n openbao svc/openbao 8200:8200"
    echo -e "$yellow Ingress:$blue http://openbao.localtest.me"
}

function install_helm_mongodb_operator(){
    echo -e "$yellow Installing MongoDB Kubernetes Operator (MCK) with helm"
    
    helm repo add mongodb https://mongodb.github.io/helm-charts
    helm repo update
    (helm upgrade --install mongodb-kubernetes-operator mongodb/mongodb-kubernetes \
        --namespace mongodb \
        --create-namespace \
        --set operator.watchedResources='{mongodbcommunity}' || 
    { 
        echo -e "$red 🛑 Could not install MongoDB Kubernetes Operator into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing MongoDB Kubernetes Operator"

    echo -e "$yellow\n⏰ Waiting for MongoDB Operator to be running"
    sleep 10
    (kubectl wait deployment -n mongodb mongodb-kubernetes-operator --for condition=Available=True --timeout=120s || 
    { 
        echo -e "$red 🛑 MongoDB Operator is not running ..."
        die
    }) & spinner

    show_mongodb_operator_after_installation_helm
}

function install_helm_mongodb_instance(){
    echo -e "$yellow Installing MongoDB Instance (MongoDBCommunity CR)"
    
    # Check if operator is installed
    if ! kubectl get deployment -n mongodb mongodb-kubernetes-operator &>/dev/null; then
        echo -e "$yellow MongoDB Kubernetes Operator not found. Installing it first..."
        install_helm_mongodb_operator
    fi
    
    # Create password secret
    local mongo_password="SuperSecret"
    kubectl create secret generic mongodb-instance-password \
        --from-literal=password="$mongo_password" \
        -n mongodb \
        --dry-run=client -o yaml | kubectl apply -f - &>/dev/null
    
    # Apply MongoDBCommunity CR
    echo -e "$yellow Applying MongoDBCommunity custom resource..."
    cat <<EOF | kubectl apply -f -
apiVersion: mongodbcommunity.mongodb.com/v1
kind: MongoDBCommunity
metadata:
  name: mongodb-instance
  namespace: mongodb
spec:
  members: 3
  type: ReplicaSet
  version: "8.0.16"
  security:
    authentication:
      modes: ["SCRAM"]
  users:
    - name: appuser
      db: admin
      passwordSecretRef:
        name: mongodb-instance-password
      roles:
        - name: clusterAdmin
          db: admin
        - name: userAdminAnyDatabase
          db: admin
        - name: readWriteAnyDatabase
          db: admin
      scramCredentialsSecretName: appuser-scram
  additionalMongodConfig:
    storage.wiredTiger.engineConfig.journalCompressor: zlib
EOF
    
    echo -e "$yellow ✅ Done creating MongoDB Instance CR"

    echo -e "$yellow\n⏰ Waiting for MongoDB Instance to be running"
    sleep 15
    (kubectl wait mongodbcommunity/mongodb-instance -n mongodb --for=jsonpath='{.status.phase}'=Running --timeout=300s || 
    { 
        echo -e "$red 🛑 MongoDB Instance is not running ..."
        die
    }) & spinner

    show_mongodb_instance_after_installation_helm
}

function show_mongodb_operator_after_installation_helm() {
    echo -e "$yellow\nMongoDB Kubernetes Operator (MCK) is ready"
    echo -e "$yellow\nTo create a MongoDB instance:$blue ./kl.sh install helm mongodb-instance"
    echo -e "$yellow\nOr apply your own MongoDBCommunity CR"
    echo -e "$yellow\nDocs: https://github.com/mongodb/mongodb-kubernetes/tree/master/docs/mongodbcommunity"
    echo -e "$clear"
}

function show_mongodb_instance_after_installation_helm() {
    echo -e "$yellow\nMongoDB Instance is ready to use"
    echo -e "$yellow\nTo access MongoDB, port-forward the service:"
    echo -e "$blue  kubectl port-forward -n mongodb svc/mongodb-instance-svc 27017:27017"
    echo -e "$yellow\nConnect using mongosh:"
    echo -e "$blue  mongosh \"mongodb://appuser:SuperSecret@localhost:27017/admin?directConnection=true\""
    echo -e "$yellow\nCredentials:"
    echo -e "$yellow  Username: appuser"
    echo -e "$yellow  Password: SuperSecret"
    echo -e "$yellow  Auth DB:  admin"
    echo -e "$clear"
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
    
    echo -e "$yellow\n⏰ Waiting for Postgres cluster resource to be created"
    sleep 15
    
    # Wait for the cluster resource to exist
    local max_wait=60
    local waited=0
    while ! kubectl get cluster -n postgres-cluster postgres-cluster &>/dev/null; do
        if [ $waited -ge $max_wait ]; then
            echo -e "$red 🛑 Postgres cluster resource not created after ${max_wait}s ..."
            die
        fi
        sleep 2
        waited=$((waited + 2))
    done
    
    echo -e "$yellow ⏰ Waiting for Postgres cluster to be ready"
    (kubectl wait --for=condition=Ready cluster/postgres-cluster -n postgres-cluster --timeout=300s || 
    { 
        echo -e "$red 🛑 Postgres Cluster is not ready ..."
        die
    }) & spinner
    echo -e "$yellow\nPostgres Cluster is ready to use"

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

function install_helm_kite(){
    local post_msg="\nPort forward: kubectl -n kite port-forward svc/kite 15001:8080\nOpen: http://localhost:15001\n"

    echo -e "$yellow Installing Kite"
    helm repo add kite https://zxh326.github.io/kite
    (helm upgrade --install kite kite/kite \
        --namespace kite \
        --create-namespace \
        --set ingress.enabled=true \
        --set ingress.className=nginx \
        --set ingress.hosts[0].host=kite.localtest.me \
        --set ingress.hosts[0].paths[0].path=/ \
        --set ingress.hosts[0].paths[0].pathType=Prefix || { 
        echo -e "$red 🛑 Could not install Kite into cluster ..."; 
        die 
    }) & spinner

    echo -e "$yellow\n⏰ Waiting for Kite to be ready"
    sleep 10
    (kubectl wait pods --for=condition=Ready --all -n kite --timeout=180s || { 
        echo -e "$red 🛑 Kite is not ready ..."; 
        die 
    }) & spinner

    echo -e "$yellow ✅ Done installing Kite"
    
    # Show access information
    local http_port
    http_port=$(get_current_cluster_http_port)
    
    echo -e "$yellow\nTo access Kite UI:"
    echo -e "$yellow Via port-forward:$blue kubectl -n kite port-forward svc/kite 15001:8080"
    echo -e "$yellow Then open: http://localhost:15001"
    
    echo -e "$yellow\nVia ingress:"
    if [[ $(is_running_more_than_one_cluster) == "yes" ]]; then
        echo -e "$yellow Open:$blue http://kite.localtest.me:$http_port"
    elif [ "$http_port" != "80" ]; then
        echo -e "$yellow Open:$blue http://kite.localtest.me:$http_port"
    else
        echo -e "$yellow Open:$blue http://kite.localtest.me"
    fi
    
    echo -e "$yellow\nℹ️  First-time setup:"
    echo -e "$yellow 1. Register a new account in the Kite UI"
    echo -e "$yellow 2. Log in with your credentials"
    echo -e "$yellow 3. Click 'Add Cluster' and select 'In-Cluster' mode"
    echo -e "$yellow 4. Name your cluster (e.g., 'local') and save"
    echo -e "$yellow\nKite will then auto-discover and display your cluster resources!"
}

function install_helm_nats(){
    echo -e "$yellow Installing NATS"
    helm repo add nats https://nats-io.github.io/k8s/helm/charts/
    (helm upgrade --install nats nats/nats --namespace nats --create-namespace || { 
        echo -e "$red 🛑 Could not install NATS into cluster ..."; 
        die 
    }) & spinner

    echo -e "$yellow\n⏰ Waiting for NATS pods to be ready"
    sleep 10
    (kubectl wait pods --for=condition=Ready --all -n nats --timeout=180s || { 
        echo -e "$red 🛑 NATS is not ready ..."; 
        die 
    }) & spinner

    echo -e "$yellow ✅ Done installing NATS"
    echo -e "$yellow To publish test message:$blue kubectl -n nats exec -it deploy/nats-box -- nats pub test hi"
    echo -e "$yellow To subscribe:$blue kubectl -n nats exec -it deploy/nats-box -- nats sub test"
}

function install_helm_metrics_server(){
    echo -e "$yellow Installing Metrics Server"
    helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
    (helm upgrade --install metrics-server metrics-server/metrics-server \
        --namespace kube-system \
        --set args[0]="--kubelet-insecure-tls" \
        --set args[1]="--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname" || { 
        echo -e "$red 🛑 Could not install Metrics Server into cluster ..."; 
        die 
    }) & spinner

    echo -e "$yellow\n⏰ Waiting for Metrics Server to be ready"
    sleep 10
    (kubectl wait deployment -n kube-system metrics-server --for condition=Available=True --timeout=120s || { 
        echo -e "$red 🛑 Metrics Server is not ready ..."; 
        die 
    }) & spinner

    echo -e "$yellow ✅ Done installing Metrics Server"
    echo -e "$yellow Verify metrics are available:$blue kubectl top nodes"
    echo -e "$yellow Check pod metrics:$blue kubectl top pods -A"
}

function install_helm_kube_prometheus_stack(){
    echo -e "$yellow Installing Kube Prometheus Stack (Prometheus, Grafana, Alertmanager)"
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    (helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace prometheus \
        --create-namespace \
        --set prometheusOperator.admissionWebhooks.patch.podAnnotations."sidecar\.istio\.io/inject"="false" || { 
        echo -e "$red 🛑 Could not install Kube Prometheus Stack into cluster ..."; 
        die 
    }) & spinner

    echo -e "$yellow\n⏰ Waiting for Prometheus Operator to be ready"
    sleep 15
    (kubectl wait deployment -n prometheus prometheus-kube-prometheus-operator --for condition=Available=True --timeout=180s || { 
        echo -e "$red 🛑 Prometheus Operator is not ready ..."; 
        die 
    }) & spinner

    echo -e "$yellow\n⏰ Waiting for Grafana to be ready"
    (kubectl wait deployment -n prometheus prometheus-grafana --for condition=Available=True --timeout=180s || { 
        echo -e "$red 🛑 Grafana is not ready ..."; 
        die 
    }) & spinner

    echo -e "$yellow ✅ Done installing Kube Prometheus Stack"
    echo -e "$yellow\nTo access the Grafana dashboard, type:$blue kubectl port-forward -n prometheus services/prometheus-grafana 3000:80"
    echo -e "$yellow\nOpen the dashboard in your browser: http://localhost:3000"
    echo -e "$yellow\nUsername: admin"
    echo -e "$yellow\nPassword: prom-operator"
    echo -e "$yellow\nAccess Prometheus UI:$blue kubectl port-forward -n prometheus services/prometheus-kube-prometheus-prometheus 9090:9090"
    echo -e "$yellow\nAccess Alertmanager UI:$blue kubectl port-forward -n prometheus services/prometheus-kube-prometheus-alertmanager 9093:9093"
}

function install_helm_cilium(){
    local cluster_name="${1:-}"
    local provider="${2:-}"
    
    echo -e "$yellow Installing Cilium CNI"
    
    # Detect provider if not provided
    if [ -z "$provider" ] && [ -n "$cluster_name" ]; then
        provider=$(get_cluster_provider "$cluster_name")
    fi
    
    # Label namespace for Talos if needed (must be done before helm install)
    source "$PWD/scripts/installers/registry.sh"
    label_namespace_for_talos "kube-system"
    
    # Set provider-specific parameters
    local k8s_service_host=""
    local k8s_service_port=""
    local extra_cilium_params=()
    
    if [ "$provider" == "talos" ]; then
        # Talos-specific configuration (Docker-based)
        k8s_service_host="localhost"
        k8s_service_port="7445"
        extra_cilium_params=(
            --set "securityContext.capabilities.ciliumAgent={CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}"
            --set "securityContext.capabilities.cleanCiliumState={NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}"
            --set "cgroup.autoMount.enabled=false"
            --set "cgroup.hostRoot=/sys/fs/cgroup"
            --set "bpf.hostLegacyRouting=true"
            --set "image.pullPolicy=IfNotPresent"
            --set "k8sServiceHost=$k8s_service_host"
            --set "k8sServicePort=$k8s_service_port"
        )
    elif [ "$provider" == "kind" ]; then
        # Kind-specific configuration (Docker-based)
        # For Kind, use default in-cluster API server discovery (don't set k8sServiceHost/Port)
        extra_cilium_params=(
            --set "image.pullPolicy=IfNotPresent"
        )
    fi
    
    helm repo add cilium https://helm.cilium.io/
    (helm upgrade --install cilium cilium/cilium \
        --namespace kube-system \
        --set operator.replicas=1 \
        --set ipam.mode=kubernetes \
        --set kubeProxyReplacement=true \
        --set "tolerations[0].operator=Exists" \
        --set "operator.tolerations[0].operator=Exists" \
        "${extra_cilium_params[@]}" || { 
        echo -e "$red 🛑 Could not install Cilium into cluster ..."; 
        die 
    }) & spinner

    echo -e "$yellow\n⏰ Waiting for Cilium to be ready"
    sleep 15
    
    # Wait for Cilium agent daemonset to be ready (core component)
    (kubectl rollout status daemonset/cilium -n kube-system --timeout=180s || { 
        echo -e "$red 🛑 Cilium agent daemonset not ready ..."; 
        die 
    }) & spinner
    
    # Wait for Cilium operator deployment to be ready
    (kubectl rollout status deployment/cilium-operator -n kube-system --timeout=60s 2>/dev/null || true) & spinner

    echo -e "$yellow ✅ Done installing Cilium"
    echo -e "$yellow Check Cilium status:$blue kubectl -n kube-system exec ds/cilium -- cilium status"
    echo -e "$yellow Run connectivity test:$blue cilium connectivity test"
}

function install_helm_calico(){
    local cluster_name="${1:-}"
    local provider="${2:-}"
    
    echo -e "$yellow Installing Calico CNI"
    
    # Detect provider if not provided
    if [ -z "$provider" ] && [ -n "$cluster_name" ]; then
        provider=$(get_cluster_provider "$cluster_name")
    fi
    
    # Label namespace for Talos if needed (must be done before helm install)
    source "$PWD/scripts/installers/registry.sh"
    label_namespace_for_talos "tigera-operator"
    
    # Set provider-specific parameters
    local extra_calico_params=()
    
    if [ "$provider" == "talos" ]; then
        # Talos-specific configuration
        extra_calico_params=(
            --set "installation.cni.type=Calico"
        )
    fi
    
    helm repo add projectcalico https://docs.tigera.io/calico/charts
    (helm upgrade --install calico projectcalico/tigera-operator \
        --namespace tigera-operator \
        --create-namespace \
        --set installation.kubernetesProvider="" \
        "${extra_calico_params[@]}" || { 
        echo -e "$red 🛑 Could not install Calico into cluster ..."; 
        die 
    }) & spinner

    echo -e "$yellow\n⏰ Waiting for Calico to be ready"
    sleep 15
    
    # Wait for Calico node daemonset to be ready (core component)
    (kubectl rollout status daemonset/calico-node -n calico-system --timeout=180s || { 
        echo -e "$red 🛑 Calico node daemonset not ready ..."; 
        die 
    }) & spinner
    
    # Wait for Calico controller deployment to be ready
    (kubectl rollout status deployment/calico-kube-controllers -n calico-system --timeout=60s 2>/dev/null || true) & spinner

    echo -e "$yellow ✅ Done installing Calico"
    echo -e "$yellow Check Calico status:$blue kubectl get pods -n calico-system"
    echo -e "$yellow Check Calico nodes:$blue kubectl get nodes -o wide"
}

function install_helm_keycloak(){
    echo -e "$yellow Installing Keycloak"
    
    # Check for StorageClass (required for PostgreSQL)
    # Try to get provider from context
    local context cluster_name provider
    context=$(kubectl config current-context 2>/dev/null || true)
    if [[ "$context" == kind-* ]]; then
        cluster_name="${context#kind-}"
    elif [[ "$context" == admin@* ]]; then
        cluster_name="${context#admin@}"
    fi
    
    # Get provider from clusterinfo.txt if available
    if [ -n "$cluster_name" ] && [ -n "${clustersDir:-}" ]; then
        local provider_file="$clustersDir/$cluster_name/provider.txt"
        if [ -f "$provider_file" ]; then
            provider=$(cat "$provider_file")
        fi
    fi
    
    if [[ "$provider" == "talos" ]]; then
        local default_sc
        default_sc=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
        if [ -z "$default_sc" ]; then
            echo -e "$red\n🛑 ERROR: No default StorageClass found!"
            echo -e "$yellow\nKeycloak requires PostgreSQL, which needs persistent storage."
            echo -e "$yellow\nFor Talos clusters, you can install storage providers:"
            echo -e "$yellow\n  OpenEBS (local-path):$blue ./kl.sh install helm localpathprovisioner"
            echo -e "$yellow  Rook Ceph (distributed):$blue ./kl.sh install helm rookcephoperator && ./kl.sh install helm rookcephcluster"
            echo -e "$yellow  NFS (network):$blue ./kl.sh install helm nfs"
            echo -e "$yellow\nAfter installing, set it as default:$blue kubectl patch storageclass <name> -p '{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}'"
            die
        fi
        echo -e "$yellow ✓ StorageClass found: $default_sc"
    fi
    
    # Check if PostgreSQL is installed
    if ! kubectl get namespace postgres-cluster &>/dev/null || ! kubectl get service -n postgres-cluster postgres-cluster-rw &>/dev/null; then
        echo -e "$yellow\n📊 PostgreSQL is required for Keycloak but not found."
        echo -e "$yellow Installing PostgreSQL (Cloud Native PG)..."
        install_helm_postgres
    else
        echo -e "$yellow ✓ PostgreSQL cluster found"
    fi
    
    # Create Keycloak database and user
    echo -e "$yellow\n🔧 Setting up Keycloak database in PostgreSQL"
    
    # Get postgres superuser password
    local postgres_password
    postgres_password=$(kubectl get secrets -n postgres-cluster postgres-cluster-superuser -o jsonpath='{.data.password}' | base64 -d)
    
    # Create keycloak database and user
    echo -e "$yellow Creating keycloak database and user..."
    local keycloak_password
    keycloak_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    kubectl run -n postgres-cluster postgres-client --rm -i --restart=Never --image=postgres:16 -- \
        psql "postgresql://postgres:${postgres_password}@postgres-cluster-rw:5432/postgres" <<EOF 2>/dev/null || true
-- Create keycloak database if it doesn't exist
SELECT 'CREATE DATABASE keycloak' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'keycloak')\gexec

-- Create keycloak user if it doesn't exist, or update password if it does
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'keycloak') THEN
        CREATE USER keycloak WITH PASSWORD '${keycloak_password}';
    ELSE
        ALTER USER keycloak WITH PASSWORD '${keycloak_password}';
    END IF;
END
\$\$;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
\\c keycloak
GRANT ALL ON SCHEMA public TO keycloak;
EOF
    
    # Create secret for Keycloak database password
    kubectl create secret generic keycloak-db-secret \
        --from-literal=password="${keycloak_password}" \
        -n keycloak \
        --dry-run=client -o yaml | kubectl apply -f - &>/dev/null
    
    echo -e "$yellow ✓ Database setup complete"
    
    # Install Keycloak
    helm repo add codecentric https://codecentric.github.io/helm-charts
    (helm upgrade --install keycloak codecentric/keycloakx \
        --namespace keycloak \
        --create-namespace \
        --set command[0]="/opt/keycloak/bin/kc.sh" \
        --set args[0]="start-dev" \
        --set replicas=1 \
        --set http.relativePath="/" \
        --set database.vendor="postgres" \
        --set database.hostname="postgres-cluster-rw.postgres-cluster.svc.cluster.local" \
        --set database.port=5432 \
        --set database.database="keycloak" \
        --set database.username="keycloak" \
        --set database.existingSecret="keycloak-db-secret" \
        --set database.existingSecretKey="password" \
        --set cache.stack="custom" \
        --set extraEnv="- name: KEYCLOAK_ADMIN\n  value: admin\n- name: KEYCLOAK_ADMIN_PASSWORD\n  value: admin" \
        --set ingress.enabled=true \
        --set ingress.ingressClassName=nginx \
        --set ingress.rules[0].host=keycloak.localtest.me \
        --set ingress.rules[0].paths[0].path=/ \
        --set ingress.rules[0].paths[0].pathType=Prefix \
        --set ingress.annotations."nginx\.ingress\.kubernetes\.io/backend-protocol"=HTTP \
        --set-json='tls=[]' || { 
        echo -e "$red 🛑 Could not install Keycloak into cluster ..."; 
        die 
    }) & spinner

    echo -e "$yellow\n⏰ Waiting for Keycloak to be ready"
    sleep 15
    (kubectl wait pods -n keycloak -l app.kubernetes.io/name=keycloakx --for=condition=Ready --timeout=300s || { 
        echo -e "$red 🛑 Keycloak is not ready ..."; 
        die 
    }) & spinner

    echo -e "$yellow ✅ Done installing Keycloak"
    
    # Show access information
    local http_port
    http_port=$(get_current_cluster_http_port)
    
    echo -e "$yellow\nTo access Keycloak UI:"
    echo -e "$yellow Via port-forward:$blue kubectl port-forward -n keycloak svc/keycloak-http 15003:80"
    echo -e "$yellow Then open: http://localhost:15003"
    
    echo -e "$yellow\nVia ingress:"
    if [[ $(is_running_more_than_one_cluster) == "yes" ]]; then
        echo -e "$yellow Open:$blue http://keycloak.localtest.me:$http_port"
    elif [ "$http_port" != "80" ]; then
        echo -e "$yellow Open:$blue http://keycloak.localtest.me:$http_port"
    else
        echo -e "$yellow Open:$blue http://keycloak.localtest.me"
    fi
    
    echo -e "$yellow\nDefault admin credentials:"
    echo -e "$yellow   Username: admin"
    echo -e "$yellow   Password: admin"
    echo -e "$yellow\nDatabase: PostgreSQL (postgres-cluster)"
    echo -e "$yellow   Database: keycloak"
    echo -e "$yellow   User: keycloak"
}

function install_multus_cni(){
    local multus_type="${1:-thin}"  # thin or thick
    
    echo -e "$yellow Installing Multus CNI ($multus_type plugin)"
    echo -e "$yellow"
    echo -e "$yellow 📝 Multus plugin types:"
    echo -e "$yellow   • thin:  Lightweight shim that delegates to your primary CNI (Cilium/Calico)"
    echo -e "$yellow            Best for most use cases, minimal overhead, depends on main CNI"
    echo -e "$yellow   • thick: Standalone binary with built-in IPAM and network configuration"
    echo -e "$yellow            Independent of main CNI, can manage networks directly"
    echo -e "$clear"
    
    # Set manifest URL based on type
    local multus_manifest_url=""
    if [ "$multus_type" == "thick" ]; then
        multus_manifest_url="https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml"
        echo -e "$yellow Using thick plugin (standalone with full features)"
    else
        multus_manifest_url="https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset.yml"
        echo -e "$yellow Using thin plugin (delegates to main CNI, recommended)"
    fi
    
    echo -e "$yellow Applying Multus manifest from: $multus_manifest_url"
    (kubectl apply -f "$multus_manifest_url" || { 
        echo -e "$red 🛑 Could not install Multus CNI into cluster ..."; 
        echo -e "$red Manifest URL: $multus_manifest_url";
        die 
    }) & spinner

    echo -e "$yellow\n⏰ Waiting for Multus CNI to be ready"
    sleep 10
    
    # Wait for Multus daemonset to be ready
    (kubectl rollout status daemonset/kube-multus-ds -n kube-system --timeout=120s || { 
        echo -e "$red 🛑 Multus CNI daemonset not ready ..."; 
        die 
    }) & spinner

    echo -e "$yellow ✅ Done installing Multus CNI"
    echo -e "$yellow"
    echo -e "$yellow 📚 Multus allows attaching multiple network interfaces to pods"
    echo -e "$yellow    Use cases: SR-IOV, macvlan, bridge networks, network segmentation"
    echo -e "$yellow"
    echo -e "$yellow 📖 Next steps:"
    echo -e "$yellow    1. Create NetworkAttachmentDefinition CRDs to define additional networks"
    echo -e "$yellow    2. Annotate pods with: k8s.v1.cni.cncf.io/networks=<net-attach-def-name>"
    echo -e "$yellow"
    echo -e "$yellow 🔍 Check status:$blue"
    echo -e "$blue    kubectl get network-attachment-definitions -A"
    echo -e "$blue    kubectl get pods -n kube-system -l app=multus"
    echo -e "$clear"
}