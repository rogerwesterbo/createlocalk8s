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

function install_helm_redis_stack(){
    # Add redis-stack helm repo and install redis-stack-server
    helm_install_generic \
        "redis-stack-server" \
        "redis-stack" \
        "https://redis-stack.github.io/helm-redis-stack" \
        "redis-stack-server" \
        "redis" \
        "" \
        "kubectl wait pods --for=condition=Ready --all -n redis --timeout=180s" \
        "\nRedis Stack is ready to use\nTo access Redis CLI: kubectl exec -it -n redis deploy/redis-stack-server -- redis-cli\n"

    echo -e "\nTo access Redis locally (port-forward), run: kubectl port-forward -n redis svc/redis-stack-server 6379:6379"
    echo -e "Connect using redis-cli: redis-cli -h localhost -p 6379"
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

function install_helm_kite(){
    local post_msg="\nPort forward: kubectl -n kite port-forward svc/kite 8080:8080\nOpen: http://localhost:8080\n"

    helm_install_generic \
        "kite" \
        "kite" \
        "https://zxh326.github.io/kite" \
        "kite" \
        "kite" \
        "" \
        "kubectl wait pods --for=condition=Ready --all -n kite --timeout=180s" \
        "$post_msg"
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
    echo -e "$yellow\nTo access the Grafana dashboard, type:$blue kubectl port-forward -n prometheus services/prometheus-grafana 30000:80"
    echo -e "$yellow\nOpen the dashboard in your browser: http://localhost:30000"
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