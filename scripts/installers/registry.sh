#!/bin/bash
# Unified lightweight registry (portable, no Bash 4 features)
# Format: key|type|function|description|namespace_label
#   type: helm|app
#   function: existing install function to invoke
#   namespace_label: (optional) namespace that needs pod-security label for Talos

# Reusable function to label namespace for Talos pod security
label_namespace_for_talos() {
  local ns="$1"
  if [ -z "$ns" ]; then
    echo -e "${red}[ERROR] Namespace not provided for labeling${clear}" >&2
    return 1
  fi
  
  # Detect provider from current context if K8S_PROVIDER is not set
  local provider="${K8S_PROVIDER:-}"
  if [ -z "$provider" ]; then
    # Try to detect from kubectl context
    local context=$(kubectl config current-context 2>/dev/null)
    if [[ "$context" == admin@* ]]; then
      # Talos context format: admin@clustername
      provider="talos"
    elif [[ "$context" == kind-* ]]; then
      # Kind context format: kind-clustername
      provider="kind"
    fi
  fi
  
  # Check if provider is Talos
  if [ "$provider" = "talos" ]; then
    echo -e "${yellow}[Talos] Labeling namespace '$ns' with pod-security.kubernetes.io/enforce=privileged${clear}"
    # Create namespace if it doesn't exist
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
    kubectl label ns "$ns" pod-security.kubernetes.io/enforce=privileged --overwrite 2>/dev/null || {
      echo -e "${yellow}[WARN] Could not label namespace $ns${clear}" >&2
    }
  fi
}

APP_HELM_REGISTRY_DATA="$(cat <<'EOF'
argocd|helm|install_helm_argocd|ArgoCD GitOps controller
metallb|helm|install_helm_metallb|MetalLB load balancer
mongodb-operator|helm|install_helm_mongodb_operator|MongoDB Kubernetes Operator (MCK)|mongodb
mongodb-instance|helm|install_helm_mongodb_instance|MongoDB Instance (MongoDBCommunity CR)|mongodb
trivy|helm|install_helm_trivy|Trivy security operator
vault|helm|install_helm_vault|HashiCorp Vault server
openbao|helm|install_helm_openbao|OpenBao secrets manager (dev mode)|openbao
falco|helm|install_helm_falco|Falco runtime security
postgres|helm|install_helm_postgres|CloudNativePG operator + cluster|postgres
pgadmin|helm|install_helm_pgadmin|PgAdmin4 UI
rook-ceph-operator|helm|install_helm_rook_ceph_operator|Rook Ceph operator
rook-ceph-cluster|helm|install_helm_rook_ceph_cluster|Rook Ceph cluster
crossplane|helm|install_helm_crossplane|Crossplane control plane
nginx|helm|install_helm_nginx_controller|Ingress-Nginx controller
minio|helm|install_helm_minio|MinIO operator
nfs|helm|install_helm_nfs|NFS external provisioner
local-path-provisioner|helm|install_helm_local_path_provisioner|Local Path Provisioner (Rancher)|local-path-storage
valkey|helm|install_helm_valkey|Valkey key-value store|valkey
nats|helm|install_helm_nats|NATS messaging server
kite|helm|install_helm_kite|Kite Kubernetes dashboard
metrics-server|helm|install_helm_metrics_server|Metrics Server for resource metrics|kube-system
prometheus|helm|install_helm_kube_prometheus_stack|Kube Prometheus Stack (Prometheus/Grafana/Alertmanager)|prometheus
cilium|helm|install_helm_cilium|Cilium CNI networking and security|kube-system
calico|helm|install_helm_calico|Calico CNI networking and security|tigera-operator
keycloak|helm|install_helm_keycloak|Keycloak identity and access management|keycloak
EOF
)"

APP_ARGO_REGISTRY_DATA="$(cat <<'EOF'
nyancat|app|install_nyancat_application|Sample Nyancat demo application
certmanager|app|install_cert_manager_application|Cert-Manager for certificates
prometheus|app|install_kube_prometheus_stack_application|Kube Prometheus Stack (Grafana/Prometheus/Alertmanager)|prometheus
kubeview|app|install_kubeview_application|Kubeview UI
opencost|app|install_opencost_application|OpenCost cost monitoring
metallb|app|install_metallb_application|MetalLB load balancer
mongodb-operator|app|install_mongodb_operator_application|MongoDB Kubernetes Operator (MCK)|mongodb
mongodb-instance|app|install_mongodb_instance|MongoDB Instance CR (Mongodb Operator must be installed)|mongodb
falco|app|install_falco_application|Falco runtime security
trivy|app|install_trivy_application|Trivy operator
vault|app|install_vault_application|HashiCorp Vault server
openbao|app|install_openbao_application|OpenBao secrets manager (dev mode)|openbao
postgres|app|install_postgres_application|CloudNativePG operator + cluster|postgres
pgadmin|app|install_pgadmin_application|PgAdmin4 UI
rook-ceph-operator|app|install_rook_ceph_operator_application|Rook Ceph operator
rook-ceph-cluster|app|install_rook_ceph_cluster_application|Rook Ceph cluster
crossplane|app|install_crossplane_application|Crossplane control plane
nginx|app|install_nginx_controller_application|Ingress-Nginx controller
minio|app|install_minio_application|MinIO operator
nfs|app|install_nfs_application|NFS external provisioner
local-path-provisioner|app|install_local_path_provisioner_application|Local Path Provisioner (Rancher)|local-path-storage
valkey|app|install_valkey_application|Valkey key-value store|valkey
nats|app|install_nats_application|NATS messaging server
kite|app|install_kite_application|Kite Kubernetes dashboard
metrics-server|app|install_metrics_server_application|Metrics Server for resource metrics|kube-system
keycloak|app|install_keycloak_application|Keycloak identity and access management|keycloak
kubevirt|app|install_kubevirt_application|KubeVirt virtual machine management|kubevirt
EOF
)"

registry_all() {
  printf '%s\n' "$APP_HELM_REGISTRY_DATA" "$APP_ARGO_REGISTRY_DATA"
}

registry_filter_type() {
  local t="$1"
  registry_all | awk -F'|' -v T="$t" 'NF && $2==T {print}'
}

registry_find() { # args: type key
  local t="$1" k="$2"
  registry_filter_type "$t" | awk -F'|' -v K="$k" '$1==K {print; exit}'
}

registry_list_pretty() { # arg: type
  local t="$1"
  registry_filter_type "$t" | awk -F'|' '{printf "%-25s %-10s %s\n", $1, $2, $4}' | sort
}

registry_install_many() { # type, comma/space list
  local t="$1" list="$2" item line fn ns_label
  # normalize list: commas -> spaces
  list=$(echo "$list" | tr ',' ' ')
  for item in $list; do
    [ -z "$item" ] && continue
    line=$(registry_find "$t" "$item") || {
      echo -e "${red}[ERROR] Unknown $t item: $item${clear}" >&2; return 1; }
    fn=$(echo "$line" | awk -F'|' '{print $3}')
    ns_label=$(echo "$line" | awk -F'|' '{print $5}')
    if ! declare -f "$fn" >/dev/null 2>&1; then
      echo -e "${red}[ERROR] Install function $fn not found for $item${clear}" >&2; return 1
    fi
    
    # Apply namespace label if needed (for Talos)
    if [ -n "$ns_label" ]; then
      label_namespace_for_talos "$ns_label"
    fi
    
    echo -e "${yellow}==> Installing $t item: $item ($fn)${clear}"
    "$fn" || return 1
  done
}
