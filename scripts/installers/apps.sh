#!/bin/bash

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
    if [[ $(is_running_more_than_one_cluster) == "yes" ]]; then
        echo -e "$yellow Open the following URL in your browser:$blue http://nyancat.localtest.me:<cluster http port>"
        echo -e "$yellow Find the cluster http port in file: $cluster_info_file)"
    else
        echo -e "$yellow Open the following URL in your browser:$blue http://nyancat.localtest.me"
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

    echo -e "$yellow To access the kube-prometheus-stack dashboard, type: $red kubectl port-forward -n prometheus services/prometheus-grafana 30000:80"
    echo -e "$yellow\n Open the dashboard in your browser: http://localhost:30000"

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
    echo -e "$yellow\nTo access the kube-prometheus-stack dashboard, type: $red kubectl port-forward -n kubeview pods/<the pod name> 59000:8000"
    echo -e "$yellow Open the dashboard in your browser: http://localhost:59000"
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
    sleep 10
    (kubectl wait pods --for=condition=Ready --all -n postgres-cluster --timeout=120s || 
    { 
        echo -e "$red 🛑 Postgres Cluster is not running, and is not ready to use ..."
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
    echo -e "$yellow\nTo access the Redis Stack dashboard, type:$blue kubectl port-forward --namespace redis service/redis-stack-server 6379:6379"
    echo -e "$yellow\nOpen the dashboard in your browser: http://localhost:6379"
}

function post_pgadmin_install() {
    echo -e "$yellow\n⏰ Waiting for Pgadmin4 to be running"
    sleep 10
    (kubectl wait pods --for=condition=Ready --all -n pgadmin --timeout=120s || 
    { 
        echo -e "$red 🛑 Falco is not running, and is not ready to use ..."
        die
    }) & spinner

    echo -e "$yellow
    PgAdmin4 is ready to use
    "
    echo -e "$yellow
    PgAdmin4 admin GUI portforwarding:$blue kubectl port-forward -n pgadmin services/pgadmin-pgadmin4 5050:80
    PgAdmin4 admin GUI url: http://localhost:5050
    "
    echo -e "$yellow
    PgAdmin4 username: chart@domain.com
    PgAdmin4 password: SuperSecret
    "

    echo -e "$yellow
    Get available services by typing$blue kubectl get services -A
    Use the ip to the service when connecting to the postgres instance 
    "
}

function show_vault_after_installation() {
    echo -e "$yellow\nVaut is ready to use"
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
        echo -e "$red 🛑 Could not install nginx ingress controller into cluster ..."
        die
    }) & spinner

    echo -e "$yellow\nUnsealing the vault"
    (kubectl exec -i -n vault vault-0 -- vault operator init -format=json > vault-init.json || 
    { 
        echo -e "$red 🛑 Could not install unseal the vault ..."
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