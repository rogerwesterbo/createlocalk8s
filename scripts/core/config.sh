#!/bin/bash

function print_logo() {
    echo -e "$blue"

    echo ""
    echo "██╗  ██╗ █████╗ ███████╗    ██╗      ██████╗  ██████╗ █████╗ ██╗     ";
    echo "██║ ██╔╝██╔══██╗██╔════╝    ██║     ██╔═══██╗██╔════╝██╔══██╗██║     ";
    echo "█████╔╝ ╚█████╔╝███████╗    ██║     ██║   ██║██║     ███████║██║     ";
    echo "██╔═██╗ ██╔══██╗╚════██║    ██║     ██║   ██║██║     ██╔══██║██║     ";
    echo "██║  ██╗╚█████╔╝███████║    ███████╗╚██████╔╝╚██████╗██║  ██║███████╗";
    echo "╚═╝  ╚═╝ ╚════╝ ╚══════╝    ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝";
    echo ""
    echo "         Local Kubernetes Cluster Manager (kind + docker)             ";
    echo ""
}

function print_help() {
    echo -e "$yellow"
    echo "Kind specific:"    
    echo "  list                            alias: ls      Show kind clusters"
    echo "  create [cluster-name]           alias: c       Create a local cluster with kind and docker"
    echo "  details <cluster-name>          alias: dt      Show details for a cluster"
    echo "  k8sdetails <cluster-name>       alias: k8s     Show detailed Kubernetes resources info"
    echo "  kubeconfig <cluster-name>       alias: kc      Get kubeconfig for a cluster by name"
    echo "  delete <cluster-name>           alias: d       Delete a cluster by name"
    echo "  help                            alias: h       Print this Help"
    echo ""
    echo "Examples:"
    echo "  ./kl.sh create mycluster                       Create cluster named 'mycluster'"
    echo "  ./kl.sh details mycluster                      Show details for cluster 'mycluster'"
    echo "  ./kl.sh k8sdetails mycluster                   Show K8s resources for cluster 'mycluster'"
    echo "  ./kl.sh delete mycluster                       Delete cluster 'mycluster'"
    echo ""
    echo "Helm installations:"
    printf "  %-40s %s\n" "helm list" "List available Helm components"
    printf "  %-40s %s\n" "install helm redis-stack,nats" "Install one or more Helm components"
    printf "  %-40s %s\n" "install helm redis-stack --dry-run" "Dry run (show what would be installed)"
    echo ""
    echo "ArgoCD application installations:"
    printf "  %-40s %s\n" "apps list" "List available ArgoCD app components"
    printf "  %-40s %s\n" "install apps nyancat,prometheus" "Install one or more ArgoCD apps"
    printf "  %-40s %s\n" "install apps nats,redis-stack --dry-run" "Dry run for ArgoCD apps"
    echo ""
    echo "Notes:"
    echo "  - Parameters in [brackets] are optional"
    echo "  - Parameters in <brackets> are required"
    echo "  - Use comma-separated lists (no spaces): redis-stack,nats"
    echo "  - Components are installed in the order specified"
    echo "  - Use --dry-run to preview changes before applying"
    echo ""
    echo "dependencies: docker, kind, kubectl, jq, base64 and helm"
    echo ""
    now=$(date)
    printf "Current date and time in Linux %s\n" "$now"
    echo ""
}

perform_action() {
  local cmd="$1"; shift || true
  case "$cmd" in
    help|h)
      print_logo; print_help; exit;;
    create|c)
      print_logo; get_cluster_parameter "$@"; exit;;
    details|dt)
      details_for_cluster "$@"; exit;;
    k8sdetails|k8s)
      show_kubernetes_details "$@"; exit;;
    info|i)
      details_for_cluster "$@"; exit;;
    delete|d)
      delete_cluster "$@"; exit;;
    list|ls)
      list_clusters "$@"; exit;;
    kubeconfig|kc)
      get_kubeconfig "$@"; exit;;
    helm)
      local sub="$1"; shift || true
      case "$sub" in
        list)
          echo -e "${yellow}Available Helm components:${clear}"
          registry_list_pretty helm
          exit;;
        *)
          echo -e "${red}Usage: ./create-cluster.sh helm list${clear}"; exit 1;;
      esac;;
    apps)
      local sub="$1"; shift || true
      case "$sub" in
        list)
          echo -e "${yellow}Available ArgoCD application components:${clear}"
          registry_list_pretty app
          exit;;
        *)
          echo -e "${red}Usage: ./create-cluster.sh apps list${clear}"; exit 1;;
      esac;;
    install)
      local target_type dry_run=false items
      target_type="$1"; shift || true
      items="$1"; shift || true
      # collect remaining flags
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --dry-run) dry_run=true; shift;;
          *) echo -e "${red}Unknown flag for install: $1${clear}"; exit 1;;
        esac
      done
      if [[ -z $target_type || -z $items ]]; then
         echo -e "${red}Usage: ./create-cluster.sh install <helm|apps> <name1,name2> [--dry-run]${clear}"; exit 1
      fi
      if [[ $items == all ]]; then
         echo -e "${red}'all' no longer supported. List items explicitly.${clear}"; exit 1
      fi
      # Normalize type: apps -> app
      local registry_type="$target_type"
      [[ $registry_type == "apps" ]] && registry_type="app"
      
      case "$target_type" in
        helm|apps)
          if $dry_run; then
            echo -e "${yellow}[dry-run] Would install $target_type items:${clear}" 
            echo "  $(echo "$items" | tr ',' ' ')"
            echo -e "${yellow}Functions:${clear}"
            IFS=',' read -r -a arr <<< "$items"
            for it in "${arr[@]}"; do
              line=$(registry_find "$registry_type" "$it") || { echo -e "${red}Unknown $target_type item: $it${clear}"; exit 1; }
              fn=$(echo "$line" | awk -F'|' '{print $3}')
              desc=$(echo "$line" | awk -F'|' '{print $4}')
              printf "  %-18s -> %-25s %s\n" "$it" "$fn" "$desc"
            done
            exit 0
          else
            registry_install_many "$registry_type" "$items" || exit 1
            exit 0
          fi;;
        *) echo -e "${red}Unknown install target type: $target_type${clear}"; exit 1;;
      esac;;
    *)
      print_logo
      echo -e "${red}Invalid command. See help.${clear}"
      print_help
      exit 1;;
  esac
}