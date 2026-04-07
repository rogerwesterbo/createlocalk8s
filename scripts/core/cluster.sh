#!/bin/bash

# Cluster operations - now provider-agnostic
# Uses provider abstraction layer for provider-specific operations

# Validate that a cluster exists, exit with error if not found
function validate_cluster_exists() {
    local clusterName="$1"
    local provider="${2:-}"

    if [ -z "$clusterName" ]; then
        echo -e "${red}\n🛑 Cluster name cannot be empty${clear}"
        exit 1
    fi

    # Determine provider
    if [ -z "$provider" ]; then
        provider=$(get_cluster_provider "$clusterName")
    fi

    # Load provider and validate
    load_provider "$provider" || exit 1
    call_provider_function "$provider" "validate_cluster_exists" "$clusterName"
}

# Validate that a cluster does NOT exist, exit with error if found
function validate_cluster_not_exists() {
    local clusterName="$1"
    local provider="${2:-kind}"  # Default to kind for new clusters

    if [ -z "$clusterName" ]; then
        echo -e "${red}\n🛑 Cluster name cannot be empty${clear}"
        exit 1
    fi

    # Check if cluster exists across ALL providers, not just the one being created
    local existing_provider=""

    # Check kind clusters
    if command -v kind &> /dev/null; then
        if kind get clusters 2>/dev/null | grep -q "^${clusterName}$"; then
            existing_provider="kind"
        fi
    fi

    # Check talos clusters (only if not already found in kind)
    # Only check for actual running infrastructure (containers/VMs), not leftover directories
    # from failed creation attempts - the provider's create function handles stale dir cleanup
    if [ -z "$existing_provider" ]; then
        # Check Docker containers matching talos naming convention
        if command -v docker &> /dev/null; then
            if docker ps -a --filter "name=^${clusterName}-controlplane-1$" --format "{{.Names}}" 2>/dev/null | grep -q "^${clusterName}-controlplane-1$"; then
                existing_provider="talos"
            fi
        fi
        # Check for running QEMU VMs
        if [ -z "$existing_provider" ]; then
            if [ -f "$clustersDir/$clusterName/backend.txt" ] && [ "$(cat "$clustersDir/$clusterName/backend.txt" 2>/dev/null)" == "qemu" ]; then
                if pgrep -f "qemu.*${clusterName}" >/dev/null 2>&1; then
                    existing_provider="talos"
                fi
            fi
        fi
    fi

    # If cluster exists with any provider, show error
    if [ -n "$existing_provider" ]; then
        echo -e "${red}\n🛑 Cluster '${clusterName}' already exists (provider: ${existing_provider})${clear}"
        echo -e "${yellow}\nPlease choose a different name or delete the existing cluster first:${clear}"
        echo -e "  ${blue}./kl.sh delete ${clusterName}${clear}"
        echo -e "\n${yellow}Available clusters:${clear}"
        list_clusters
        exit 1
    fi
}

# Show error when cluster name parameter is missing
function show_missing_cluster_name_error() {
    local command_name="$1"
    local command_alias="$2"

    echo -e "${red}\n🛑 Missing cluster name parameter${clear}"
    echo -e "${yellow}\nUsage:${clear}"
    echo -e "  ${blue}./kl.sh ${command_name} <cluster-name>${clear}"

    if [ -n "$command_alias" ]; then
        echo -e "  ${blue}./kl.sh ${command_alias} <cluster-name>${clear}"
    fi

    echo -e "\n${yellow}Example:${clear}"
    echo -e "  ${blue}./kl.sh ${command_name} mycluster${clear}"

    echo -e "\n${yellow}To see available clusters, run:${clear}"
    echo -e "  ${blue}./kl.sh list${clear}"

    exit 1
}

function show_kubernetes_details() {
    if [[ "$#" -lt 1 ]]; then
        show_missing_cluster_name_error "k8sdetails" "k8s"
    fi

    if [[ "$#" -gt 1 ]]; then
        echo "Too many arguments"
        exit 1
    fi

    local clusterName="$1"

    # Validate cluster exists
    validate_cluster_exists "$clusterName"

    # Get provider and context
    local provider=$(get_cluster_provider "$clusterName")
    load_provider "$provider" || exit 1
    local context=$(call_provider_function "$provider" "get_cluster_context" "$clusterName")

    # Switch context
    switch_to_cluster_context "$context"

    echo -e "$blue"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "                    📊 Kubernetes Cluster Details                              "
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo -e "$clear"

    # Use provider-agnostic function
    get_kubernetes_details

    echo -e "$blue"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo -e "$clear"
}

function list_clusters() {
    echo -e "$yellow 🚀 K8s local Clusters:$clear\n"

    # List all clusters from all providers
    local all_clusters=()

    # Check kind clusters
    if command -v kind &> /dev/null; then
        local kind_clusters=$(kind get clusters 2>/dev/null)
        if [ -n "$kind_clusters" ] && [ "$kind_clusters" != "No kind clusters found." ]; then
            while IFS= read -r cluster; do
                [ -z "$cluster" ] && continue
                echo -e "  ${blue}$cluster${clear} ${yellow}(kind)${clear}"
                all_clusters+=("$cluster")
            done <<< "$kind_clusters"
        fi
    fi

    # Check talos clusters
    if command -v talosctl &> /dev/null; then
        local talos_clusters=""
        
        # Docker-based Talos clusters
        local docker_talos
        docker_talos=$(docker ps -a --filter "name=-controlplane-1$" --format "{{.Names}}" 2>/dev/null | sed 's/-controlplane-1$//' | sort -u)
        if [ -n "$docker_talos" ]; then
            talos_clusters="$docker_talos"
        fi
        
        # Talos clusters from cluster directories (QEMU or orphaned Docker clusters)
        if [ -d "$clustersDir" ]; then
            for dir in "$clustersDir"/*/; do
                [ -d "$dir" ] || continue
                local name
                name=$(basename "$dir")
                # Detect talos clusters by provider.txt, backend.txt, or talos/ subdir
                local is_talos=false
                if [ -f "$dir/provider.txt" ] && [ "$(cat "$dir/provider.txt")" == "talos" ]; then
                    is_talos=true
                elif [ -f "$dir/backend.txt" ]; then
                    is_talos=true
                elif [ -d "$dir/talos" ]; then
                    is_talos=true
                fi
                if [ "$is_talos" == "true" ]; then
                    talos_clusters="$talos_clusters
$name"
                fi
            done
        fi
        
        talos_clusters=$(echo "$talos_clusters" | grep -v '^$' | sort -u)
        if [ -n "$talos_clusters" ]; then
            while IFS= read -r cluster; do
                [ -z "$cluster" ] && continue
                # Only list if not already listed as kind
                local found=false
                for existing_cluster in "${all_clusters[@]}"; do
                    if [[ "$existing_cluster" == "$cluster" ]]; then
                        found=true
                        break
                    fi
                done

                if ! $found; then
                    echo -e "  ${blue}$cluster${clear} ${yellow}(talos)${clear}"
                    all_clusters+=("$cluster")
                fi
            done <<< "$talos_clusters"
        fi
    fi

    if [ ${#all_clusters[@]} -eq 0 ]; then
        echo -e "  ${yellow}No clusters found${clear}"
    fi
}

function get_kubeconfig() {
    if [ "$#" -lt 1 ]; then
        show_missing_cluster_name_error "kubeconfig" "kc"
    fi

    if [ "$#" -gt 1 ]; then
        echo "Too many arguments"
        exit 1
    fi

    local clusterName="$1"
    if [ -z "$clusterName" ]; then
        show_missing_cluster_name_error "kubeconfig" "kc"
    fi

    # Validate cluster exists
    validate_cluster_exists "$clusterName"

    # Get provider
    local provider=$(get_cluster_provider "$clusterName")
    load_provider "$provider" || exit 1

    # Use provider-specific kubeconfig function
    local output_file="$clustersDir/$clusterName/kubeconfig"
    if ! call_provider_function "$provider" "get_kubeconfig" "$clusterName" "$output_file"; then
        echo -e "${red}\n🛑 Could not retrieve kubeconfig for cluster '${clusterName}'.${clear}"
        return 1
    fi

    echo -e "$yellow Kubeconfig saved to $output_file"
    echo -e "$yellow To use the kubeconfig, type:$red export KUBECONFIG=$output_file"
    echo -e "$yellow And then you can use $blue kubectl$yellow to interact with the cluster"
    echo -e "$yellow Example: $blue kubectl get nodes"
    echo ""
}

function delete_cluster() {
    if [[ "$#" -lt 1 ]]; then
        show_missing_cluster_name_error "delete" "d"
    fi

    if [[ "$#" -gt 1 ]]; then
        echo "Too many arguments"
        exit 1
    fi

    local clusterName="$1"
    clusterName=$(echo "$clusterName" | tr '[:upper:]' '[:lower:]')

    # Validate cluster exists
    validate_cluster_exists "$clusterName"

    echo -e "$yellow\nDeleting cluster $clusterName"
    read -p "Are you sure you want to delete? (n | no | y | yes)? " ok

    if [ "$ok" == "yes" ] ;then
            echo -e "$yellow\nDeleting cluster ..."
        elif [ "$ok" == "y" ]; then
            echo -e "$yellow\nDeleting cluster ..."
        elif [ "$ok" == "n" ]; then
            echo -e "$red\nThat was a close one! Not deleting!"
            exit 0
        elif [ "$ok" == "no" ]; then
            echo -e "$red\nThat was a close one! Not deleting!"
            exit 0
        else
            echo "🛑 Did not detect any confirmation, I need you to confirm with a yes or y 😀 ... quitting"
            exit 0
    fi

    # Get provider
    local provider=$(get_cluster_provider "$clusterName")
    load_provider "$provider" || exit 1

    # Use provider-specific delete function
    if ! call_provider_function "$provider" "delete_cluster" "$clusterName"; then
        echo -e "$red 🛑 Cluster deletion failed. Cluster directory preserved so you can retry.$clear"
        exit 1
    fi

    echo -e "$yellow ✅ Done deleting cluster"

    # Clean up cluster directory
    rm -rf "${clustersDir:?}/${clusterName:?}" 2>/dev/null

    # Also clean up old-style files for backward compatibility
    rm -f "${clustersDir:?}/${clusterName:?}-provider.txt" 2>/dev/null
    rm -f "${clustersDir:?}/${clusterName:?}-clusterinfo.txt" 2>/dev/null
    rm -f "${clustersDir:?}/${clusterName:?}-config.yaml" 2>/dev/null
    rm -f "${clustersDir:?}/${clusterName:?}-kube.config" 2>/dev/null
    rm -rf "${clustersDir:?}/${clusterName:?}-talos" 2>/dev/null
}

function details_for_cluster() {
    if [[ "$#" -lt 1 ]]; then
        show_missing_cluster_name_error "details" "dt"
    fi

    if [[ "$#" -gt 1 ]]; then
        echo "Too many arguments"
        exit 1
    fi

    local clusterName="$1"

    # Validate cluster exists
    validate_cluster_exists "$clusterName"

    # Build file paths using the provided cluster name
    local cluster_dir="$clustersDir/$clusterName"
    local cluster_info_file_path
    local config_file_path
    cluster_info_file_path=$(get_abs_filename "$cluster_dir/clusterinfo.txt")

    local provider=$(get_cluster_provider "$clusterName")
    if [ "$provider" == "kind" ]; then
        config_file_path=$(get_abs_filename "$cluster_dir/config.yaml")
    else
        config_file_path=$(get_abs_filename "$cluster_dir/talos/talosconfig")
    fi

    echo -e "$yellow\nCluster details for $clusterName"

    if [ -f "$cluster_info_file_path" ]; then
        cat "$cluster_info_file_path"
    else
        echo -e "$red\nCluster info file not found: $cluster_info_file_path"
    fi

    echo -e "$yellow\nProvider configuration for $clusterName (provider: $provider)"

    if [ -f "$config_file_path" ]; then
        cat "$config_file_path"
    else
        echo -e "$red\nConfig file not found: $config_file_path"
    fi
}

function get_cluster_parameter() {
    detect_os
    check_prerequisites
    ensure_docker_running
    check_docker_hub_login

    # Parse command line arguments for provider
    local provider=""  # Will be set interactively or via flag
    local provider_from_flag=false
    local cluster_name_arg=""
    local args=("$@")
    local i=0

    while [ $i -lt ${#args[@]} ]; do
        arg="${args[$i]}"
        case "$arg" in
            --provider)
                i=$((i + 1))
                if [ $i -lt ${#args[@]} ]; then
                    provider="${args[$i]}"
                    provider_from_flag=true
                fi
                ;;
            --provider=*)
                provider="${arg#*=}"
                provider_from_flag=true
                ;;
            *)
                if [ -z "$cluster_name_arg" ]; then
                    cluster_name_arg="$arg"
                fi
                ;;
        esac
        i=$((i + 1))
    done

    # If provider not specified via flag, ask interactively
    if [ -z "$provider" ]; then
        echo -e "$clear"
        echo -e "$yellow Available providers:$clear"
        echo -e "  ${blue}1)${clear} kind   - Kubernetes in Docker (fast, default)"
        echo -e "  ${blue}2)${clear} talos  - Talos Linux (immutable, production-like)"
        echo ""
        read -p "Select provider (1 for kind, 2 for talos) [default: 1]: " provider_choice

        case "$provider_choice" in
            2)
                provider="talos"
                echo -e "$yellow ✅ Provider set to: ${blue}talos${clear}"
                ;;
            1|"")
                provider="kind"
                echo -e "$yellow ✅ Provider set to: ${blue}kind${clear}"
                ;;
            *)
                echo -e "$red Invalid choice. Using default: kind${clear}"
                provider="kind"
                ;;
        esac
        echo -e "$clear"
    fi

    # Load the provider
    load_provider "$provider" || {
        echo -e "${red}Failed to load provider: $provider${clear}"
        exit 1
    }

    # Check provider prerequisites
    echo -e "${yellow}🔍 Checking prerequisites for provider '$provider'...${clear}"
    if ! call_provider_function "$provider" "check_prerequisites"; then
        echo -e "${red} 🛑 Prerequisite check failed for provider '$provider'. Please install missing tools.${clear}"
        exit 1
    fi
    echo -e "${yellow}✅ Prerequisites check passed${clear}"

    # Get cluster name
    if [ -z "$cluster_name_arg" ]; then
        echo -e "$clear"
        read -p "Enter the cluster name (default: $cluster_name): " cluster_name_new
        if [ -n "$cluster_name_new" ]; then
            cluster_name=$cluster_name_new
            echo -e "$yellow ✅ Cluster name set to: $blue$cluster_name"
            echo -e "$clear"
        else
            echo -e "$yellow ✅ Using default cluster name: $blue$cluster_name"
            echo -e "$clear"
        fi
    else
        cluster_name="$cluster_name_arg"
        echo -e "$yellow ✅ Cluster name: $blue$cluster_name"
        echo -e "$clear"
    fi

    cluster_name=$(echo "$cluster_name" | tr '[:upper:]' '[:lower:]')

    # Validate cluster name is unique
    validate_cluster_not_exists "$cluster_name" "$provider"

    # For Talos provider: Ask for backend selection first (affects control plane options)
    talos_backend="docker"
    talos_version=""
    if [ "$provider" == "talos" ]; then
        # Get talosctl version early (needed for backend selection info)
        talos_version=$(talos_get_version)
        
        if [ -z "$talos_version" ]; then
            echo -e "${red}Could not determine talosctl version. Is talosctl installed?${clear}"
            die
        fi
        
        echo -e "${yellow}Detected talosctl version: ${blue}v${talos_version}${clear}"
        
        local talos_major_minor
        talos_major_minor=$(echo "$talos_version" | awk -F. '{print $1"."$2}')
        
        # Only show backend selection for v1.12+ (older versions don't have subcommands)
        if [[ "$talos_major_minor" == "1.12" ]] || [[ "${talos_major_minor%%.*}" -gt 1 ]]; then
            echo -e "$yellow"
            echo -e "$yellow 🖥️  Talos Backend Selection$clear"
            echo -e "$yellow   📌 docker (recommended): Fast startup, lightweight, runs in Docker containers$clear"
            echo -e "$yellow      • Quick local testing and development$clear"
            echo -e "$yellow      • Single control plane only$clear"
            echo -e "$yellow"
            echo -e "$yellow   📌 qemu: Full VM emulation, production-like environment$clear"
            echo -e "$yellow      • Multiple control planes supported$clear"
            echo -e "$yellow      • Requires QEMU installation$clear"
            echo -e "$yellow      • Better for KubeVirt and disk operations$clear"
            echo -e "$clear"
            read -p "Select Talos backend (docker/qemu) (default: docker): " talos_backend_new
            if [ "$talos_backend_new" == "qemu" ]; then
                # Check for QEMU binary before accepting the choice
                local qemu_bin=""
                if command -v qemu-system-aarch64 &>/dev/null; then
                    qemu_bin="qemu-system-aarch64"
                elif command -v qemu-system-x86_64 &>/dev/null; then
                    qemu_bin="qemu-system-x86_64"
                elif command -v qemu-kvm &>/dev/null; then
                    qemu_bin="qemu-kvm"
                fi

                if [ -z "$qemu_bin" ]; then
                    echo -e "${red}❌ QEMU is not installed. The QEMU backend requires a QEMU binary.${clear}"
                    echo -e "${yellow}   Install QEMU for your platform:${clear}"
                    echo -e "${yellow}   macOS:   ${blue}brew install qemu${clear}"
                    echo -e "${yellow}   Ubuntu:  ${blue}sudo apt install qemu-system${clear}"
                    echo -e "${yellow}   Fedora:  ${blue}sudo dnf install qemu-system-x86 qemu-system-aarch64${clear}"
                    echo -e "${yellow}   Arch:    ${blue}sudo pacman -S qemu-full${clear}"
                    echo ""
                    local fallback_docker=""
                    read -r -p "$(echo -e "${yellow}   Do you want to use the Docker backend instead? (y/n): ${clear}")" fallback_docker
                    if [[ "$fallback_docker" == "y" || "$fallback_docker" == "Y" ]]; then
                        talos_backend="docker"
                        echo -e "$yellow ✅ Using Docker backend (container-based)$clear"
                    else
                        echo -e "${red}   Aborting cluster creation.${clear}"
                        return 1
                    fi
                else
                    talos_backend="qemu"
                    echo -e "$yellow ✅ Using QEMU backend (full VM emulation)$clear"
                fi
            else
                talos_backend="docker"
                echo -e "$yellow ✅ Using Docker backend (container-based)$clear"
            fi
            echo -e "$clear"
        fi
    fi

    # Get cluster parameters
    # For Talos docker backend on v1.12+, skip control plane question (always 1)
    local skip_controlplane_prompt=false
    if [ "$provider" == "talos" ] && [ "$talos_backend" == "docker" ]; then
        local talos_major_minor
        talos_major_minor=$(echo "$talos_version" | awk -F. '{print $1"."$2}')
        if [[ "$talos_major_minor" == "1.12" ]] || [[ "${talos_major_minor%%.*}" -gt 1 ]]; then
            skip_controlplane_prompt=true
            controlplane_number=1
            echo -e "$yellow ✅ Control planes: ${blue}1${yellow} (Docker backend supports single control plane only)$clear"
            echo -e "$clear"
        fi
    fi

    if [ "$skip_controlplane_prompt" == "false" ]; then
        read -p "Enter number of control planes (default: 1): " controlplane_number_new
        if [ -n "$controlplane_number_new" ]; then
            controlplane_number=$controlplane_number_new
            echo -e "$yellow ✅ Control planes set to: $blue$controlplane_number"
            echo -e "$clear"
        else
            echo -e "$yellow ✅ Using default control planes: $blue$controlplane_number"
            echo -e "$clear"
        fi
    fi

    read -p "Enter number of workers (default: 0): " worker_number_new
    if [ -n "$worker_number_new" ]; then
        worker_number=$worker_number_new
        echo -e "$yellow ✅ Workers set to: $blue$worker_number"
        echo -e "$clear"
    else
        echo -e "$yellow ✅ Using default workers: $blue$worker_number"
        echo -e "$clear"
    fi

    # Only ask for Kubernetes version if using kind provider
    if [ "$provider" == "kind" ]; then
        read -p "Enter version of Kubernetes (available:$kindk8spossibilities default: $kindk8sversion): " selected_k8s_version
        check_k8s_version=""
        selected_k8s_version=$(echo "$selected_k8s_version" | tr '[:upper:]' '[:lower:]')
        if [ -n "$selected_k8s_version" ]; then
            for version in "${kindk8sversions[@]}"; do
                IFS=':' read -r k8s_version kind_image <<< "$version"
                if [ "$selected_k8s_version" == "$k8s_version" ]; then
                    kindk8simage=$kind_image
                    kindk8sversion=$k8s_version
                    check_k8s_version=$k8s_version
                fi
            done

            if [ -z "$check_k8s_version" ]; then
                echo -e "$red 🛑 Kubernetes version $selected_k8s_version is not available. Next time, please select from the available versions: $kindk8spossibilities"
                die
            fi
            echo -e "$yellow ✅ Selected Kubernetes version: $blue$kindk8sversion"
            echo -e "$clear"
        else
            echo -e "$yellow ✅ Using default Kubernetes version: $blue$kindk8sversion"
            echo -e "$clear"
        fi
    else
        # For Talos, dynamically get supported versions based on installed talosctl version
        # Note: talos_version was already set earlier during backend selection
        
        # Populate talosk8sversions array based on installed talosctl version
        talos_populate_k8s_versions || {
            echo -e "${red}Could not determine supported Kubernetes versions for Talos${clear}"
            die
        }
        
        local talosk8sversion_default="${talosk8sversions[0]}"
        
        # More robustly join the array for display.
        local joined_versions
        printf -v joined_versions '%s,' "${talosk8sversions[@]}"
        local talosk8spossibilities="${joined_versions%,}" # Remove trailing comma

        # Set default for the script's generic variable
        kindk8sversion=$talosk8sversion_default

        read -p "Enter Kubernetes version for Talos (available: $talosk8spossibilities, default: $talosk8sversion_default): " selected_k8s_version
        if [ -n "$selected_k8s_version" ]; then
            local valid_version=false
            for version in "${talosk8sversions[@]}"; do
                if [[ "$selected_k8s_version" == "$version" ]]; then
                    kindk8sversion=$selected_k8s_version
                    valid_version=true
                    break
                fi
            done

            if ! $valid_version; then
                echo -e "$red 🛑 Kubernetes version $selected_k8s_version is not available for Talos. Please select from the available versions: $talosk8spossibilities"
                die
            fi
            echo -e "$yellow ✅ Selected Kubernetes version: $blue$kindk8sversion"
            echo -e "$clear"
        else
            echo -e "$yellow ✅ Using default Kubernetes version: $blue$kindk8sversion"
            echo -e "$clear"
        fi

        # Ask for memory size (Talos only)
        talos_memory=4096
        read -p "Enter memory size for Talos nodes in MB (default: 4096): " talos_memory_new
        if [ -n "$talos_memory_new" ]; then
            talos_memory=$talos_memory_new
            echo -e "$yellow ✅ Memory per node set to: $blue${talos_memory}MB"
            echo -e "$clear"
        else
            echo -e "$yellow ✅ Using default memory per node: $blue${talos_memory}MB"
            echo -e "$clear"
        fi
    fi

    install_nginx_controller="yes"

    read -p "Install ArgoCD with Helm? (default: yes) (y/yes | n/no): " install_argocd_new
    if [ "$install_argocd_new" == "yes" ] || [ "$install_argocd_new" == "y" ] || [ "$install_argocd_new" == "" ]; then
        install_argocd="yes"
        echo -e "$yellow ✅ ArgoCD will be installed"
        echo -e "$clear"
    else
        install_argocd="no"
        echo -e "$yellow ✅ ArgoCD will NOT be installed"
        echo -e "$clear"
    fi

    # Ask about CNI
    custom_cni="default"
    install_multus="no"
    multus_type="thin"
    
    echo -e "$yellow Available CNI (Container Network Interface) options:$clear"
    read -p "Use custom CNI? (default/cilium/calico) (default: default): " cni_choice
    if [ "$cni_choice" == "cilium" ]; then
        custom_cni="cilium"
        echo -e "$yellow ✅ Will disable default CNI and allow Cilium installation"
        echo -e "$clear"
    elif [ "$cni_choice" == "calico" ]; then
        custom_cni="calico"
        echo -e "$yellow ✅ Will disable default CNI and allow Calico installation"
        echo -e "$clear"
    else
        custom_cni="default"
        echo -e "$yellow ✅ Using default CNI"
        echo -e "$clear"
    fi

    # Ask about Multus CNI (only if Cilium or Calico is selected)
    if [ "$custom_cni" == "cilium" ] || [ "$custom_cni" == "calico" ]; then
        echo -e "$yellow"
        echo -e "$yellow 📡 Multus CNI - Multiple Network Interfaces for Pods$clear"
        echo -e "$yellow    Enables pods to have multiple network interfaces (SR-IOV, macvlan, bridge, etc.)$clear"
        echo -e "$yellow    Useful for: Network segmentation, high-performance networking, legacy apps$clear"
        echo -e "$clear"
        read -p "Install Multus CNI? (yes/no) (default: no): " multus_choice
        if [ "$multus_choice" == "yes" ]; then
            install_multus="yes"
            echo -e "$yellow"
            echo -e "$yellow Choose Multus plugin type:$clear"
            echo -e "$yellow   📌 thin  (recommended): Lightweight shim, delegates to $custom_cni$clear"
            echo -e "$yellow      • Low overhead, simple configuration$clear"
            echo -e "$yellow      • Depends on primary CNI for pod networking$clear"
            echo -e "$yellow      • Best for most use cases$clear"
            echo -e "$yellow"
            echo -e "$yellow   📌 thick: Standalone binary with built-in IPAM$clear"
            echo -e "$yellow      • Independent network management$clear"
            echo -e "$yellow      • Can manage networks without primary CNI$clear"
            echo -e "$yellow      • More complex, use for advanced scenarios$clear"
            echo -e "$clear"
            read -p "Multus plugin type? (thin/thick) (default: thin): " multus_type_choice
            if [ "$multus_type_choice" == "thick" ]; then
                multus_type="thick"
                echo -e "$yellow ✅ Will install Multus CNI with thick plugin (standalone)"
            else
                multus_type="thin"
                echo -e "$yellow ✅ Will install Multus CNI with thin plugin (delegates to $custom_cni)"
            fi
            echo -e "$clear"
        else
            echo -e "$yellow ℹ️  Multus CNI will NOT be installed"
            echo -e "$clear"
        fi
    fi

    # Determine ports
    read -p "Determine cluster ports (http_port https_port)" ports <<< $(determine_cluster_ports "$provider")
    controlplane_port_http=$(echo $ports | awk '{print $1}')
    controlplane_port_https=$(echo $ports | awk '{print $2}')

    first_controlplane_port_http=$controlplane_port_http
    first_controlplane_port_https=$controlplane_port_https

    # Generate provider-specific config
    if [ "$provider" == "kind" ]; then
        local cluster_dir="$clustersDir/$cluster_name"
        mkdir -p "$cluster_dir"
        kind_config_file=$(get_abs_filename "$cluster_dir/config.yaml")
        echo -e "$yellow\nKind config file: $kind_config_file"

        kind_generate_config "$cluster_name" "$kind_config_file" "$kindk8simage" \
            "$controlplane_number" "$worker_number" \
            "$controlplane_port_http" "$controlplane_port_https" "$custom_cni"

        config_file="$kind_config_file"
    elif [ "$provider" == "talos" ]; then
        local cluster_dir="$clustersDir/$cluster_name"
        mkdir -p "$cluster_dir/talos"
        config_file="$cluster_dir/talos"
    fi

    # Display summary
    echo -e "$yellow\n⏰ Creating $provider cluster with the following configuration"

    echo -en "$yellow\nCluster name:"
    echo -en "$blue $cluster_name"

    echo -en "$yellow\nProvider:"
    echo -en "$blue $provider"

    echo -en "$yellow\nHow many control planes?:"
    echo -en "$blue $controlplane_number"

    echo -en "$yellow\nHow many workers?:"
    echo -en "$blue $worker_number"

    echo -en "$yellow\nKubernetes version:"
    echo -en "$blue $kindk8sversion"

    if [ "$provider" == "talos" ]; then
        echo -en "$yellow\nBackend:"
        echo -en "$blue $talos_backend"
        echo -en "$yellow\nMemory per node:"
        echo -en "$blue ${talos_memory}MB"
    fi

    echo -en "$yellow\nInstall Nginx ingress controller?:"
    echo -en "$blue $install_nginx_controller"

    echo -en "$yellow\nInstall ArgoCD with Helm?:"
    echo -en "$blue $install_argocd"

    echo -en "$yellow\nCNI:"
    echo -en "$blue $custom_cni"

    if [ "$install_multus" == "yes" ]; then
        echo -en "$yellow\nMultus CNI:"
        echo -en "$blue yes ($multus_type plugin)"
    fi

    echo -en "$yellow\nCluster http port:"
    echo -en "$blue $first_controlplane_port_http"

    echo -en "$yellow\nCluster https port:"
    echo -en "$blue $first_controlplane_port_https"

    echo ""
    echo -e "$clear"
    read -p "Looks ok (n | no | y | yes)? " ok

    if [ "$ok" == "yes" ] ;then
            echo "Excellent 👌"
            create_cluster "$provider"
        elif [ "$ok" == "y" ]; then
            echo "Good 🤌"
            create_cluster "$provider"
        else
            echo "🛑 Did not detect any confirmation, I need you to confirm with a yes or y 😀 ... quitting"
            exit 0
    fi
}

function create_cluster() {
    local provider="$1"

    if [ -z "$cluster_name" ] || [ "$controlplane_number" -lt 1 ] || [ "$worker_number" -lt 0 ]; then
        echo "Not all parameters are valid ... quitting"
        die
    fi

    # Double-check cluster doesn't exist before creating
    validate_cluster_not_exists "$cluster_name" "$provider"

    # Save provider for this cluster
    set_cluster_provider "$cluster_name" "$provider"

    # Use provider-specific cluster creation
    call_provider_function "$provider" "create_cluster" \
        "$cluster_name" "$config_file" "$kindk8sversion" \
        "$controlplane_number" "$worker_number" \
        "$first_controlplane_port_http" "$first_controlplane_port_https" "$custom_cni" "${talos_memory:-4096}" "${talos_backend:-docker}" || {
        echo -e "${red} 🛑 Cluster creation failed${clear}"
        die
    }

    # Get the context name
    local context=$(call_provider_function "$provider" "get_cluster_context" "$cluster_name")

    # Ensure kubectl is using the correct context
    switch_to_cluster_context "$context"

    # Install CNI first if custom CNI is selected (nodes need to be ready before other components)
    if [ "$custom_cni" != "default" ]; then
        echo -e "${yellow}\n📦 Installing $custom_cni CNI via Helm (making nodes ready first)...${clear}"
        if [ "$custom_cni" == "cilium" ]; then
            install_helm_cilium "$cluster_name" "$provider"
        elif [ "$custom_cni" == "calico" ]; then
            install_helm_calico "$cluster_name" "$provider"
        fi
        
        # Install Multus CNI if requested (after primary CNI is ready)
        if [ "$install_multus" == "yes" ]; then
            echo -e "${yellow}\n📦 Installing Multus CNI ($multus_type plugin)...${clear}"
            install_multus_cni "$multus_type"
        fi
    fi

    # Setup ingress (provider-specific)
    call_provider_function "$provider" "setup_ingress" "$cluster_name" \
        "$first_controlplane_port_http" "$first_controlplane_port_https"

    # Install ArgoCD after CNI (provider-agnostic)
    local argocd_password=""
    if [ "$install_argocd" == "yes" ]; then
        install_argocd_generic "$cluster_name"
        argocd_password=$(get_argocd_password)
    fi

    # Write cluster info file
    local cluster_info_file=$(get_abs_filename "$clustersDir/$cluster_name/clusterinfo.txt")
    write_cluster_info_file "$cluster_name" "$provider" "$controlplane_number" \
        "$worker_number" "$kindk8sversion" "$first_controlplane_port_http" \
        "$first_controlplane_port_https" "$install_argocd" "$argocd_password" \
        "$cluster_info_file"

    echo -e "$yellow ✅ Done creating cluster"

    # Display cluster info
    display_cluster_info "$cluster_name" "$provider" "$first_controlplane_port_http" \
        "$first_controlplane_port_https" "$install_argocd" "$argocd_password"

    # Get kubeconfig
    get_kubeconfig "$cluster_name"
    
    # For Talos multi-control-plane, show proxy container info
    if [ "$provider" == "talos" ] && [ "$controlplane_number" -gt 1 ]; then
        echo -e "${yellow}\n📦 Multi-control-plane Talos cluster uses a proxy container for ingress${clear}"
        echo -e "${yellow}   Proxy container: ${blue}${cluster_name}-ingress-proxy${clear}"
        echo -e "${yellow}   This container auto-restarts and forwards traffic to MetalLB${clear}"
    fi

    # Optionally install nyancat
    if [ "$install_argocd" == "yes" ]; then
        install_nyancat=""
        read -p "Install Nyan-cat ArgoCD application? (default: yes) (y/yes | n/no): " install_nyancat_new
        if [ "$install_nyancat_new" == "yes" ] || [ "$install_nyancat_new" == "y" ] || [ "$install_nyancat_new" == "" ]; then
            install_nyancat="yes"
        else
            install_nyancat="no"
        fi

        if [ "$install_nyancat" == "yes" ]; then
            install_nyancat_application
        fi
    fi
}
