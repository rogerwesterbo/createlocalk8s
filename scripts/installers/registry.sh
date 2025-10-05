#!/bin/bash
# Unified lightweight registry (portable, no Bash 4 features)
# Format: key|type|function|description
#   type: helm|app
#   function: existing install function to invoke

APP_HELM_REGISTRY_DATA="$(cat <<'EOF'
argocd|helm|install_helm_argocd|ArgoCD GitOps controller
metallb|helm|install_helm_metallb|MetalLB load balancer
mongodb-operator|helm|install_helm_mongodb_operator|MongoDB (Bitnami) single deployment
mongodb-instance|helm|install_helm_mongodb_instance|MongoDB additional instance (Bitnami)
trivy|helm|install_helm_trivy|Trivy security operator
vault|helm|install_helm_vault|HashiCorp Vault server
falco|helm|install_helm_falco|Falco runtime security
postgres|helm|install_helm_postgres|CloudNativePG operator + cluster
pgadmin|helm|install_helm_pgadmin|PgAdmin4 UI
rook-ceph-operator|helm|install_helm_rook_ceph_operator|Rook Ceph operator
rook-ceph-cluster|helm|install_helm_rook_ceph_cluster|Rook Ceph cluster
crossplane|helm|install_helm_crossplane|Crossplane control plane
nginx|helm|install_helm_nginx_controller|Ingress-Nginx controller
minio|helm|install_helm_minio|MinIO operator
nfs|helm|install_helm_nfs|NFS external provisioner
redis-stack|helm|install_helm_redis_stack|Redis Stack server
nats|helm|install_helm_nats|NATS messaging server
EOF
)"

APP_ARGO_REGISTRY_DATA="$(cat <<'EOF'
nyancat|app|install_nyancat_application|Sample Nyancat demo application
certmanager|app|install_cert_manager_application|Cert-Manager for certificates
prometheus|app|install_kube_prometheus_stack_application|Kube Prometheus Stack (Grafana/Prometheus/Alertmanager)
kubeview|app|install_kubeview_application|Kubeview UI
opencost|app|install_opencost_application|OpenCost cost monitoring
metallb|app|install_metallb_application|MetalLB load balancer
mongodb-operator|app|install_mongodb_operator_application|MongoDB Operator (Community)
mongodb-instance|app|install_mongodb_instance|MongoDB Instance CR
falco|app|install_falco_application|Falco runtime security
trivy|app|install_trivy_application|Trivy operator
vault|app|install_vault_application|HashiCorp Vault server
postgres|app|install_postgres_application|CloudNativePG operator + cluster
pgadmin|app|install_pgadmin_application|PgAdmin4 UI
rook-ceph-operator|app|install_rook_ceph_operator_application|Rook Ceph operator
rook-ceph-cluster|app|install_rook_ceph_cluster_application|Rook Ceph cluster
crossplane|app|install_crossplane_application|Crossplane control plane
nginx|app|install_nginx_controller_application|Ingress-Nginx controller
minio|app|install_minio_application|MinIO operator
nfs|app|install_nfs_application|NFS external provisioner
redis-stack|app|install_redis_stack_application|Redis Stack server
nats|app|install_nats_application|NATS messaging server
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
  registry_filter_type "$t" | awk -F'|' '{printf "%-18s %-10s %s\n", $1, $2, $4}' | sort
}

registry_install_many() { # type, comma/space list
  local t="$1" list="$2" item line fn
  # normalize list: commas -> spaces
  list=$(echo "$list" | tr ',' ' ')
  for item in $list; do
    [ -z "$item" ] && continue
    line=$(registry_find "$t" "$item") || {
      echo -e "${red}[ERROR] Unknown $t item: $item${clear}" >&2; return 1; }
    fn=$(echo "$line" | awk -F'|' '{print $3}')
    if ! declare -f "$fn" >/dev/null 2>&1; then
      echo -e "${red}[ERROR] Install function $fn not found for $item${clear}" >&2; return 1
    fi
    echo -e "${yellow}==> Installing $t item: $item ($fn)${clear}"
    "$fn" || return 1
  done
}
