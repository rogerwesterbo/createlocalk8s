#!/bin/bash

function is_running_more_than_one_cluster() {
    local total_clusters=0
    local talos_count=0
    local kind_count=0

    # Count running Talos clusters by calling the provider function.
    # This requires the talos-provider.sh script to be sourced.
    if command -v talosctl &> /dev/null && type talos_list_clusters &> /dev/null; then
        talos_count=$(talos_list_clusters | wc -l)
    fi

    # Count running Kind clusters using the kind CLI.
    if command -v kind &> /dev/null; then
        kind_count=$(kind get clusters 2>/dev/null | wc -l)
    fi

    total_clusters=$((talos_count + kind_count))

    if [ "$total_clusters" -gt 1 ]; then
        echo "yes"
    else
        echo "no"
    fi
}

function get_current_cluster_http_port() {
    if [ -n "${cluster_http_port_cached:-}" ]; then
        echo "$cluster_http_port_cached"
        return
    fi

    local info_file="${cluster_info_file:-}"

    if [ -z "$info_file" ] || [ ! -f "$info_file" ]; then
        if command -v kubectl >/dev/null 2>&1; then
            local context cluster_name
            context=$(kubectl config current-context 2>/dev/null || true)
            if [[ "$context" == kind-* ]]; then
                cluster_name="${context#kind-}"
            elif [[ "$context" == admin@* ]]; then
                cluster_name="${context#admin@}"
            fi

            if [ -n "$cluster_name" ] && [ -n "${clustersDir:-}" ]; then
                local candidate="$clustersDir/$cluster_name/clusterinfo.txt"
                if [ -f "$candidate" ]; then
                    info_file="$candidate"
                    if [ -z "${cluster_info_file:-}" ]; then
                        cluster_info_file="$candidate"
                    fi
                fi
            fi
        fi
    fi

    local port=""
    if [ -n "$info_file" ] && [ -f "$info_file" ]; then
        port=$(grep -m1 "Cluster http port" "$info_file" | awk -F': *' '{print $2}' | tr -d '[:space:]')
    fi

    if [ -z "$port" ]; then
        port="80"
    fi

    cluster_http_port_cached="$port"
    echo "$port"
}

function install_minio_application() {
    echo -e "$yellow Installing Minio ArgoCD application "
    (kubectl apply -f $minio_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Minio ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Minio ArgoCD application"

    echo "Minio application installed: yes" >> $cluster_info_file

    post_minio_installation
}

function post_minio_installation() {
    echo -e "$yellow Post Minio installation steps"   
}

function install_nfs_application() {
    echo -e "$yellow Installing NFS Subdirectory External Provisioner ArgoCD application "
    (kubectl apply -f $nfs_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install NFS Subdirectory External Provisioner ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing NFS Subdirectory External Provisioner ArgoCD application"

    echo "NFS Subdirectory External Provisioner application installed: yes" >> $cluster_info_file
}

function install_local_path_provisioner_application() {
    echo -e "$yellow Installing Local Path Provisioner ArgoCD application"
    (kubectl apply -f $local_path_provisioner_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Local Path Provisioner ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Local Path Provisioner ArgoCD application"

    echo -e "$yellow\n⏰ Waiting for Local Path Provisioner to be ready"
    sleep 10
    (kubectl wait deployment -n local-path-storage local-path-provisioner --for condition=Available=True --timeout=120s || 
    { 
        echo -e "$red 🛑 Local Path Provisioner is not ready ..."
        die
    }) & spinner

    echo "Local Path Provisioner application installed: yes" >> $cluster_info_file

    echo -e "$yellow\nLocal Path Provisioner is ready to use"
    echo -e "$yellow\nStorageClass 'local-path' is available for PersistentVolumeClaims"
    echo -e "$yellow\nCheck storage classes:$blue kubectl get storageclass"
    echo -e "$yellow\nCheck provisioner pods:$blue kubectl get pods -n local-path-storage"
}

function install_mongodb_operator_application() {
    echo -e "$yellow Installing Mongodb Operator ArgoCD application"
    (kubectl apply -f $mongodb_operator_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Mongodb ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Mongodb ArgoCD application"

    echo -e "$yellow ⏲ Installing Mongodb instance
    "

    echo -e "$yellow\n⏰ Waiting for Mongodb to be running"
    sleep 10
    (kubectl wait pods --for=condition=Ready --all -n mongodb --timeout=120s || 
    { 
        echo -e "$red 🛑 Mongodb is not running, and is not ready to use ..."
        die
    }) & spinner

    show_mongodb_operator_after_installation
}

function install_mongodb_instance() {
    echo -e "$yellow Installing Mongodb instance"

    # check if secret exists
    if kubectl -n mongodb get secret appuser-password >/dev/null 2>&1; then
        echo -e "$yellow Secret appuser-password already exists - skipping creation"
    else
        (kubectl -n mongodb create secret generic appuser-password --from-literal=password='SuperSecret' ||
        { 
            echo -e "$red 🛑 Could not create secret for Mongodb instance ..."
            die
        }) & spinner
    fi

    (kubectl apply -f $mongodb_instance_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Mongodb instance into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Mongodb instance"

    # waiting for Mongodb to be running
    echo -e "$yellow\n⏰ Waiting for Mongodb to be running"
    sleep 10
    (kubectl wait pods --for=condition=Ready --all -n mongodb --timeout=300s || 
    { 
        echo -e "$red 🛑 Mongodb is not running, and is not ready to use ... Check pod logs in mongodb namespace"
        die
    }) & spinner

    echo -e "$yellow\n⏰ Waiting for Mongodb instance service to be running"
    sleep 10
    (kubectl wait pods --for=condition=Ready --all -n mongodb --timeout=300s || 
    { 
        echo -e "$red 🛑 Could not install Mongodb instance service into cluster ..."
        die
    }) & spinner

    show_mongodb_after_installation
}

function show_mongodb_after_installation() {
    echo -e "$yellow\nMongodb instance is ready to use"
    echo -e "$yellow\nTo access the Mongodb dashboard, type:$blue kubectl port-forward --namespace mongodb service/mongodb-instance-svc 27017:27017"
    echo -e "$yellow\nUse mongosh to connect to the database"
    echo -e "$yellow\nExample:$blue mongosh \"mongodb://appuser:SuperSecret@localhost:27017/appdb?replicaSet=mongodb-instance&directConnection=true\""
    echo -e "$yellow\nUsername: appuser"
    echo -e "$yellow\nPassword: SuperSecret"
    echo -e "$clear"
}

function show_mongodb_operator_after_installation() {
    echo -e "$yellow\nMongodb is ready to use"
    echo -e "$yellow\nTo install a instance of mongodb type:$blue ./create-cluster.sh iamdbi "
    echo -e "$clear"
}

function install_nyancat_application(){
    echo -e "$yellow Installing Nyan-cat ArgoCD application"
    (kubectl apply -f $nyancat_argo_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Nyan-cat ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Nyan-cat ArgoCD application"
    echo -e "$yellow ⏰ Waiting for Nyancat ArgoCD application to be ready"
    sleep 10
    (kubectl wait --namespace nyan-cat --for=condition=ready pod --selector=app.kubernetes.io/name=nyan-cat --timeout=90s || 
    { 
        echo -e "$red 
        🛑 Could not install Nyan-cat ArgoCD application into cluster  ...
        "
        die
    }) & spinner

    echo "Nyancat argocd application installed: yes" >> $cluster_info_file

    echo -e "$yellow To access the Nyancat application:"
    local http_port
    http_port=$(get_current_cluster_http_port)
    if [[ $(is_running_more_than_one_cluster) == "yes" ]]; then
        echo -e "$yellow Open the following URL in your browser:$blue http://nyancat.localtest.me:$http_port"
    elif [ "$http_port" != "80" ]; then
        echo -e "$yellow Open the following URL in your browser:$blue http://nyancat.localtest.me:$http_port"
    else
        echo -e "$yellow Open the following URL in your browser:$blue http://nyancat.localtest.me"
    fi
    if [ -n "${cluster_info_file:-}" ]; then
        echo -e "$yellow Cluster details: $cluster_info_file"
    fi
}

function install_cert_manager_application() {
    (kubectl apply -n argocd -f $cert_manager_yaml||
    { 
        echo -e "$red 🛑 Could not install cert-manager to cluster"
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing cert-manager"
}

function install_kube_prometheus_stack_application() {
    (kubectl apply -n argocd -f $kube_prometheus_stack_yaml||
    { 
        echo -e "$red 🛑 Could not install kube-prometheus-stack to cluster"
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing kube-prometheus-stack"

    echo -e "$yellow To access the kube-prometheus-stack dashboard, type: $red kubectl port-forward -n prometheus services/prometheus-grafana 3000:80"
    echo -e "$yellow\n Open the dashboard in your browser: http://localhost:3000"

    echo -e "$yellow\nUsername: admin"
    echo -e "$yellow\nPassword: prom-operator"
}

function install_kubeview_application() {
    (kubectl apply -n argocd -f $kubeview_yaml||
    { 
        echo -e "$red 🛑 Could not install kubeview to cluster"
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing kubeview"
    echo -e "$yellow\nTo access the kubeview dashboard, type: $red kubectl port-forward -n kubeview pods/<the pod name> 15004:8000"
    echo -e "$yellow Open the dashboard in your browser: http://localhost:15004"
}

function install_opencost_application() {
    echo -e "$yellow Installing OpenCost ArgoCD application"
    (kubectl apply -f $opencost_argo_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install OpenCost ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing OpenCost ArgoCD application"

    echo "OpenCost argocd application installed: yes" >> $cluster_info_file

    echo -e "$yellow\nTo access the OpenCost dashboard, type: $red kubectl port-forward --namespace opencost service/opencost 9003 9090"
    echo -e "$yellow\nOpen the dashboard in your browser: http://localhost:9090"
}


function install_metallb_application() {
    echo -e "$yellow Installing Metallb ArgoCD application"
    (kubectl apply -f $metallb_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Metallb ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Metallb ArgoCD application"
    echo "Metallb application installed: yes" >> $cluster_info_file
}

function install_kite_application() {
    echo -e "$yellow Installing Kite ArgoCD application"
    (kubectl apply -f $kite_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Kite ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Kite ArgoCD application"

    echo -e "$yellow\n⏰ Waiting for ArgoCD to sync and create Kite resources"
    sleep 20
    
    # Wait for pods to be created by ArgoCD
    local max_wait=60
    local waited=0
    while ! kubectl get pods -n kite -l app.kubernetes.io/name=kite &>/dev/null || [ "$(kubectl get pods -n kite -l app.kubernetes.io/name=kite --no-headers 2>/dev/null | wc -l)" -eq 0 ]; do
        if [ $waited -ge $max_wait ]; then
            echo -e "$red 🛑 Kite pods not created by ArgoCD after ${max_wait}s ..."
            die
        fi
        sleep 2
        waited=$((waited + 2))
    done
    
    echo -e "$yellow ⏰ Waiting for Kite pods to be ready"
    (kubectl wait pods --for=condition=Ready --all -n kite --timeout=180s || { 
        echo -e "$red 🛑 Kite is not ready ..."; 
        die 
    }) & spinner

    echo "Kite application installed: yes" >> $cluster_info_file

    echo -e "$yellow ✅ Kite is ready to use"
    echo -e "$yellow\nTo access the Kite dashboard:"
    
    # Show port-forward option
    echo -e "$yellow Via port-forward:$blue kubectl -n kite port-forward svc/kite 15001:8080"
    echo -e "$yellow Then open your browser at:$blue http://localhost:15001"
    
    # Show ingress option
    local http_port
    http_port=$(get_current_cluster_http_port)
    echo -e "$yellow\nVia ingress:"
    if [[ $(is_running_more_than_one_cluster) == "yes" ]]; then
        echo -e "$yellow Open the following URL in your browser:$blue http://kite.localtest.me:$http_port"
    elif [ "$http_port" != "80" ]; then
        echo -e "$yellow Open the following URL in your browser:$blue http://kite.localtest.me:$http_port"
    else
        echo -e "$yellow Open the following URL in your browser:$blue http://kite.localtest.me"
    fi
    
    echo -e "$yellow\nℹ️  First-time setup:"
    echo -e "$yellow 1. Register a new account in the Kite UI"
    echo -e "$yellow 2. Log in with your credentials"
    echo -e "$yellow 3. Click 'Add Cluster' and select 'In-Cluster' mode"
    echo -e "$yellow 4. Name your cluster (e.g., 'local') and save"
    echo -e "$yellow\nKite will then auto-discover and display your cluster resources!"
    
    if [ -n "${cluster_info_file:-}" ]; then
        echo -e "$yellow Cluster details: $cluster_info_file"
    fi
}

function install_trivy_application() {
    echo -e "$yellow Installing Trivy ArgoCD application "
    (kubectl apply -f $trivy_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Trivy ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Trivy ArgoCD application "

    echo "Trivy application installed: yes" >> $cluster_info_file
}

function install_falco_application() {
    echo -e "$yellow Installing Falco ArgoCD application "
    (kubectl apply -f $falco_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Falco ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Falco ArgoCD application"

    echo "Falco application installed: yes" >> $cluster_info_file

    post_falco_installation
}

function install_vault_application() {
    echo -e "$yellow Installing Hashicorp Vault ArgoCD application"
    (kubectl apply -f $vault_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Vault ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Vault ArgoCD application "

    unseal_vault

    show_vault_after_installation
}

function install_postgres_application() {
    echo -e "$yellow Installing Postgres ArgoCD application"
    (kubectl apply -f $cnpg_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Cloud Native Postgres ArgoCD application into cluster  ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Cloud Native Postgres ArgoCD application"

    echo -e "$yellow\n⏰ Waiting for Cloud Native Postgres to be running"
    sleep 10
    (kubectl wait --namespace postgres-operator --for=condition=ready pod --selector=app.kubernetes.io/name=cloudnative-pg --timeout=120s || 
    { 
        echo -e "$red 🛑 Postgres Operator is not running, and is not ready to use ..."
        die
    }) & spinner
    echo -e "$yellow\nPostgres Operator is ready to use"

    (kubectl apply -f $cnpg_cluster_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Cloud Native Postgres Cluster ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Cloud Native Postgres Cluster ArgoCD application"
    
    echo -e "$yellow\n⏰ Waiting for ArgoCD to create the Postgres cluster resource"
    sleep 15
    
    # Wait for the cluster resource to be created by ArgoCD
    local max_wait=60
    local waited=0
    while ! kubectl get cluster -n postgres-cluster postgres-cluster &>/dev/null; do
        if [ $waited -ge $max_wait ]; then
            echo -e "$red 🛑 Postgres cluster resource not created by ArgoCD after ${max_wait}s ..."
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

function install_pgadmin_application() {
    echo -e "$yellow Installing PgAdmin4 ArgoCD application"
    (kubectl apply -f $pgadmin_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install PgAdmin4 ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing PgAdmin4 ArgoCD application"
    post_pgadmin_install
}

function install_rook_ceph_operator_application() {
    echo -e "$yellow Installing Rook Ceph Operator ArgoCD application"
    (kubectl apply -f $rook_ceph_operator_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Rook Ceph Operator ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Rook Ceph Operator ArgoCD application"
}

function install_rook_ceph_cluster_application() {
    echo -e "$yellow Installing Rook Ceph Cluster ArgoCD application"
    (kubectl apply -f $rook_ceph_cluster_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Rook Ceph Cluster ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Rook Ceph Cluster ArgoCD application"
}

function install_crossplane_application() {
    echo -e "$yellow Installing Crossplane ArgoCD application"
    (kubectl apply -f $crossplane_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Crossplane ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Crossplane ArgoCD application"
}

function install_nginx_controller_application() {
    echo -e "$yellow Installing Nginx Controller ArgoCD application"
    (kubectl apply -f $nginx_controller_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Nginx Controller ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Nginx Controller ArgoCD application"
}

function install_redis_stack_application() {
    echo -e "$yellow Installing Redis Stack ArgoCD application"
    (kubectl apply -f $redis_stack_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Redis Stack ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Redis Stack ArgoCD application"

    #wait for redis to be ready
    sleep 10
    (kubectl wait pods --for=condition=Ready --all -n redis --timeout=120s || 
    { 
        echo -e "$red 🛑 Redis Stack is not running, and is not ready to use ..."
        die
    }) & spinner

    echo -e "$yellow\nRedis Stack is ready to use"

    # docs with port forwarding
    echo -e "$yellow\nTo access the Redis Stack dashboard, type:$blue kubectl port-forward --namespace redis service/redis-stack-server 6380:6379"
    echo -e "$yellow\nOpen the dashboard in your browser: http://localhost:6380"
}

function install_valkey_application() {
    echo -e "$yellow Installing Valkey ArgoCD application"
    (kubectl apply -f $valkey_app_yaml|| 
    { 
        echo -e "$red 🛑 Could not install Valkey ArgoCD application into cluster ..."
        die
    }) & spinner

    echo -e "$yellow ✅ Done installing Valkey ArgoCD application"

    echo -e "$yellow\n⏰ Waiting for Valkey to be ready"
    sleep 10
    (kubectl wait pods --for=condition=Ready --all -n valkey --timeout=180s || 
    { 
        echo -e "$red 🛑 Valkey is not running, and is not ready to use ..."
        die
    }) & spinner

    echo "Valkey application installed: yes" >> $cluster_info_file

    echo -e "$yellow\nValkey is ready to use"
    echo -e "$yellow\nTo access Valkey CLI:$blue kubectl exec -it -n valkey statefulset/valkey-master -- valkey-cli"
    echo -e "$yellow\nTo access Valkey locally (port-forward):$blue kubectl port-forward -n valkey svc/valkey-master 6381:6379"
    echo -e "$yellow\nConnect using valkey-cli:$blue valkey-cli -h localhost -p 6381"
}

function install_nats_application() {
    echo -e "$yellow Installing NATS ArgoCD application"
    (kubectl apply -f $nats_app_yaml|| { 
        echo -e "$red 🛑 Could not install NATS ArgoCD application into cluster ..."; 
        die 
    }) & spinner

    echo -e "$yellow ✅ Done installing NATS ArgoCD application"

    echo -e "$yellow\n⏰ Waiting for NATS to be running"
    sleep 10
    (kubectl wait pods --for=condition=Ready --all -n nats --timeout=180s || { 
        echo -e "$red 🛑 NATS is not running, and is not ready to use ..."; 
        die 
    }) & spinner

    echo "NATS application installed: yes" >> $cluster_info_file

    echo -e "$yellow NATS ready."
    echo -e "$yellow Features: core, JetStream (mem 2Gi / file 1Gi), WebSocket:8080 (nats-ws.localtest.me), MQTT:1883, nats-box"
    echo -e "$yellow Endpoints (cluster):"
    echo -e "  nats://nats.nats.svc.cluster.local:4222"
    echo -e "  mqtt://nats.nats.svc.cluster.local:1883"
    echo -e "  ws://nats-ws.localtest.me"
    echo -e "$yellow Optional port-forward:"
    echo -e "  kubectl -n nats port-forward svc/nats 4222:4222"
    echo -e "  kubectl -n nats port-forward svc/nats 1883:1883"
    echo -e "  kubectl -n nats port-forward svc/nats 15002:8080"
    echo -e "$yellow Quick tests:"
    echo -e "  # Pub/Sub"
    echo -e "  kubectl -n nats exec deploy/nats-box -- nats sub demo.> &"
    echo -e "  kubectl -n nats exec deploy/nats-box -- nats pub demo.hello hi"
    echo -e "  # JetStream (create simple stream)"
    echo -e "  kubectl -n nats exec deploy/nats-box -- nats stream add DEMO --subjects demo.* --storage file --retention limits"
    echo -e "  kubectl -n nats exec deploy/nats-box -- nats pub demo.x test"
    echo -e "  kubectl -n nats exec deploy/nats-box -- nats stream ls"
    echo -e "  # MQTT (after port-forward if external)"
    echo -e "  mosquitto_sub -h 127.0.0.1 -p 1883 -t demo/# &"
    echo -e "  mosquitto_pub -h 127.0.0.1 -p 1883 -t demo/mqtt -m hi"
    echo -e "  # JetStream status"
    echo -e "  kubectl -n nats exec deploy/nats-box -- nats account info"
    echo -e "$yellow Docs:"
    echo -e "  https://docs.nats.io/"
    echo -e "  https://docs.nats.io/nats-concepts/jetstream"
    echo -e "  https://docs.nats.io/running-a-nats-service/configuration/websocket"
    echo -e "  https://docs.nats.io/running-a-nats-service/configuration/mqtt"
    echo -e "  https://docs.nats.io/using-nats/nats-tools/nats_cli"
}

function install_metrics_server_application() {
    echo -e "$yellow Installing Metrics Server ArgoCD application"
    (kubectl apply -f $metrics_server_app_yaml|| { 
        echo -e "$red 🛑 Could not install Metrics Server ArgoCD application into cluster ..."; 
        die 
    }) & spinner

    echo -e "$yellow ✅ Done installing Metrics Server ArgoCD application"

    echo -e "$yellow\n⏰ Waiting for Metrics Server to be ready"
    sleep 10
    (kubectl wait deployment -n kube-system metrics-server --for condition=Available=True --timeout=120s || { 
        echo -e "$red 🛑 Metrics Server is not ready ..."; 
        die 
    }) & spinner

    echo "Metrics Server application installed: yes" >> $cluster_info_file

    echo -e "$yellow Metrics Server is ready to use"
    echo -e "$yellow Verify metrics are available:$blue kubectl top nodes"
    echo -e "$yellow Check pod metrics:$blue kubectl top pods -A"
}

function install_keycloak_application() {
    echo -e "$yellow Installing Keycloak ArgoCD application"
    
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
        local default_sc=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
        if [ -z "$default_sc" ]; then
            echo -e "$red\n🛑 ERROR: No default StorageClass found!"
            echo -e "$yellow\nKeycloak requires PostgreSQL, which needs persistent storage."
            echo -e "$yellow\nFor Talos clusters, you can install storage providers:"
            echo -e "$yellow\n  OpenEBS (local-path):$blue ./kl.sh install helm localpathprovisioner"
            echo -e "$yellow  Rook Ceph (distributed):$blue ./kl.sh install apps rookcephoperator,rookcephcluster"
            echo -e "$yellow\n  NFS (network):$blue ./kl.sh install apps nfs"
            echo -e "$yellow\nAfter installing, set it as default:$blue kubectl patch storageclass <name> -p '{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}'"
            die
        fi
        echo -e "$yellow ✓ StorageClass found: $default_sc"
    fi
    
    # Check if PostgreSQL is installed
    if ! kubectl get namespace postgres-cluster &>/dev/null || ! kubectl get cluster -n postgres-cluster postgres-cluster &>/dev/null; then
        echo -e "$yellow\n📊 PostgreSQL is required for Keycloak but not found."
        echo -e "$yellow Installing PostgreSQL (Cloud Native PG)..."
        install_postgres_application
    else
        echo -e "$yellow ✓ PostgreSQL cluster found"
    fi
    
    # Create Keycloak database and user
    echo -e "$yellow\n🔧 Setting up Keycloak database in PostgreSQL"
    
    # Wait for postgres cluster to be ready
    echo -e "$yellow Waiting for PostgreSQL cluster to be ready..."
    kubectl wait --for=condition=Ready cluster/postgres-cluster -n postgres-cluster --timeout=300s &>/dev/null || {
        echo -e "$red 🛑 PostgreSQL cluster not ready"
        die
    }
    
    # Get postgres superuser password
    local postgres_password=$(kubectl get secrets -n postgres-cluster postgres-cluster-superuser -o jsonpath='{.data.password}' | base64 -d)
    
    # Create keycloak database and user
    echo -e "$yellow Creating keycloak database and user..."
    local keycloak_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
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
    (kubectl apply -f $keycloak_app_yaml|| { 
        echo -e "$red 🛑 Could not install Keycloak ArgoCD application into cluster ..."; 
        die 
    }) & spinner

    echo -e "$yellow ✅ Done installing Keycloak ArgoCD application"

    echo -e "$yellow\n⏰ Waiting for ArgoCD to sync and create Keycloak resources"
    sleep 20
    
    # Wait for statefulset to be created by ArgoCD (Keycloak uses StatefulSet, not Deployment)
    local max_wait=60
    local waited=0
    while ! kubectl get statefulset -n keycloak keycloak-keycloakx &>/dev/null; do
        if [ $waited -ge $max_wait ]; then
            echo -e "$red 🛑 Keycloak statefulset not created by ArgoCD after ${max_wait}s ..."
            die
        fi
        sleep 2
        waited=$((waited + 2))
    done
    
    echo -e "$yellow ⏰ Waiting for Keycloak to be ready"
    (kubectl wait pods -n keycloak -l app.kubernetes.io/name=keycloakx --for=condition=Ready --timeout=300s || { 
        echo -e "$red 🛑 Keycloak is not ready ..."; 
        die 
    }) & spinner

    echo "Keycloak application installed: yes" >> $cluster_info_file

    echo -e "$yellow ✅ Keycloak is ready to use"
    
    echo -e "$yellow\nTo access Keycloak UI:"
    echo -e "$yellow Via port-forward:$blue kubectl port-forward -n keycloak svc/keycloak-http 15003:80"
    echo -e "$yellow Then open: http://localhost:15003"
    
    echo -e "$yellow\nVia ingress:"
    local http_port
    http_port=$(get_current_cluster_http_port)
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

function post_pgadmin_install() {
    echo -e "$yellow\n⏰ Waiting for PgAdmin4 to be running"
    sleep 10
    (kubectl wait pods --for=condition=Ready --all -n pgadmin --timeout=120s || 
    { 
        echo -e "$red 🛑 PgAdmin4 is not running, and is not ready to use ..."
        die
    }) & spinner

    echo -e "$yellow
    PgAdmin4 is ready to use
    "
    echo -e "$yellow
    PgAdmin4 admin GUI port forwarding:$blue kubectl port-forward -n pgadmin services/pgadmin-pgadmin4 5050:80
    PgAdmin4 admin GUI URL: http://localhost:5050
    "
    echo -e "$yellow
    PgAdmin4 username: chart@domain.com
    PgAdmin4 password: SuperSecret
    "

    echo -e "$yellow
    Get available services by typing$blue kubectl get services -A
    Use the IP to the service when connecting to the Postgres instance 
    "
}

function show_vault_after_installation() {
    echo -e "$yellow\nVault is ready to use"
    echo -e "$yellow\nTo access the Vault dashboard, type:$blue kubectl port-forward --namespace vault service/vault 8200:8200"
    echo -e "$yellow\nOpen the dashboard in your browser: http://localhost:8200"
    echo -e "$yellow\nToken to use: $(jq -cr '.root_token' vault-init.json)"
    echo -e ""
}

function post_postgres_installation() {    
    echo -e "$yellow\n Port forward to access the database:$blue kubectl port-forward -n postgres-cluster services/postgres-cluster-rw 5432:5432"
    echo -e "$yellow\n Use your favorite database client to connect to the database"
    echo -e "$yellow User: postgres"
    postgres_password=$(kubectl get secrets -n postgres-cluster postgres-cluster-superuser -o json | jq -r '.data.password' | base64 -d)
    echo -e "$yellow Password: $postgres_password"
    echo -e "$yellow\n Example:$blue pgcli -h localhost -U postgres -p 5432"
    echo -e ""
}

function post_falco_installation() {
    echo -e "$yellow\n ⏰ Waiting for Falco to be running"
    sleep 10
    (kubectl wait pods --for=condition=Ready --all -n falco --timeout=120s || 
    { 
        echo -e "$red 🛑 Falco is not running, and is not ready to use ..."
        die
    }) & spinner

    echo -e "$yellow\nFalco is ready to use"
    echo -e "$yellow\nTo access the Falco dashboard, type:$blue kubectl port-forward --namespace falco services/falco-falcosidekick-ui 2802:2802"
    echo -e "$yellow\nOpen the dashboard in your browser: http://localhost:2803"
    echo -e "$yellow\nDefault credentials: admin/admin"
    echo ""
    echo -e "$yellow\nTrigger an event to test Falco by executing: $blue kubectl exec -it -n falco pods/<a pod name> -- /bin/bash"
    echo -e "$yellow\nCheck the logs by executing:$blue kubectl logs -n falco -l app.kubernetes.io/name=falco"
    echo -e "$yellow\nOr check the dashboard at: http://localhost:2803"
}

function unseal_vault() {
    echo -e "$yellow\n⏰ Waiting for vault to be running"
    sleep 10
    (kubectl wait --namespace vault --for=condition=PodReadyToStartContainers pod/vault-0 --timeout=90s || 
    { 
        echo -e "$red 🛑 Could not install Nginx ingress controller into cluster ..."
        die
    }) & spinner

    echo -e "$yellow\nUnsealing the vault"
    (kubectl exec -i -n vault vault-0 -- vault operator init -format=json > vault-init.json || 
    { 
        echo -e "$red 🛑 Could not unseal the vault ..."
        die
    }) & spinner
    echo -e "$clear"

    echo -e "$yellow\nKeys to unseal the vault"
    jq -cr '.unseal_keys_b64[]' vault-init.json

    echo -e "$yellow\nRoot token"
    jq -cr '.root_token' vault-init.json

    echo -e "$yellow\n Unseal progress"
    keys=$(jq -cr '.unseal_keys_b64[]' vault-init.json)
    for i in $keys; do
        echo "\nUnsealing vault with key: $i"
        echo "kubectl exec -i -n vault vault-0 -- vault operator unseal $i"
        kubectl exec -i -n vault vault-0 -- vault operator unseal "$i"
    done
}

function restart_argocd_after_cni() {
    # Check if ArgoCD is installed
    if kubectl get namespace argocd >/dev/null 2>&1; then
        echo -e "$yellow\n🔄 Restarting ArgoCD deployments after CNI installation..."
        (kubectl rollout restart deployment -n argocd >/dev/null 2>&1 || true) & spinner
        echo -e "$yellow⏰ Waiting for ArgoCD deployments to be ready..."
        sleep 5
        (kubectl rollout status deployment -n argocd --timeout=120s || {
            echo -e "$yellow ⚠️  ArgoCD deployments may need more time to stabilize"
        }) & spinner
        echo -e "$yellow✅ ArgoCD deployments restarted${clear}"
    fi
}

function post_cilium_installation() {
    echo -e "$yellow Post Cilium installation steps"
    echo -e "$yellow\n⏰ Waiting for Cilium to be ready"
    sleep 15
    
    # Wait for Cilium agent daemonset to be ready (core component)
    (kubectl rollout status daemonset/cilium -n kube-system --timeout=180s || 
    { 
        echo -e "$red 🛑 Cilium is not running, and is not ready to use ..."
        die
    }) & spinner
    
    # Wait for Cilium operator deployment to be ready
    (kubectl rollout status deployment/cilium-operator -n kube-system --timeout=60s 2>/dev/null || true) & spinner

    echo -e "$yellow ✅ Cilium is ready to use"
    echo -e "$yellow Check Cilium status:$blue kubectl -n kube-system exec ds/cilium -- cilium status"
    echo -e "$yellow Run connectivity test:$blue cilium connectivity test"
    
    # Restart ArgoCD if it exists
    restart_argocd_after_cni
}

function post_calico_installation() {
    echo -e "$yellow Post Calico installation steps"
    echo -e "$yellow\n⏰ Waiting for Calico to be ready"
    sleep 15
    
    # Wait for Calico node daemonset to be ready (core component)
    (kubectl rollout status daemonset/calico-node -n calico-system --timeout=180s || 
    { 
        echo -e "$red 🛑 Calico is not running, and is not ready to use ..."
        die
    }) & spinner
    
    # Wait for Calico controller deployment to be ready
    (kubectl rollout status deployment/calico-kube-controllers -n calico-system --timeout=60s 2>/dev/null || true) & spinner

    echo -e "$yellow ✅ Calico is ready to use"
    echo -e "$yellow Check Calico status:$blue kubectl get pods -n calico-system"
    echo -e "$yellow Check Calico nodes:$blue kubectl get nodes -o wide"
    
    # Restart ArgoCD if it exists
    restart_argocd_after_cni
}