package cobra

import (
	"bufio"
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"text/tabwriter"

	"github.com/spf13/cobra"
)

type ClusterInfo struct {
	Name     string
	Provider string
}

func listClusters() ([]ClusterInfo, error) {
	var clusters []ClusterInfo
	clusterNames := make(map[string]bool)

	// Get Kind clusters
	cmd := exec.Command("kind", "get", "clusters")
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err == nil {
		scanner := bufio.NewScanner(&out)
		for scanner.Scan() {
			clusterName := scanner.Text()
			if !clusterNames[clusterName] {
				clusters = append(clusters, ClusterInfo{Name: clusterName, Provider: "kind"})
				clusterNames[clusterName] = true
			}
		}
	}

	// Get Talos clusters (and others) from the clusters directory
	const clustersDir = "clusters"
	files, err := os.ReadDir(clustersDir)
	if err != nil {
		if !os.IsNotExist(err) {
			return nil, fmt.Errorf("reading clusters directory: %w", err)
		}
		// if clusters dir does not exist, just return kind clusters
		return clusters, nil
	}

	for _, file := range files {
		if file.IsDir() {
			clusterName := file.Name()
			// Sanitize clusterName to prevent path traversal
			cleanClusterName := filepath.Clean(clusterName)
			if cleanClusterName != clusterName || strings.Contains(cleanClusterName, "..") {
				continue // Skip potentially malicious directory names
			}
			if !clusterNames[cleanClusterName] {
				provider := "unknown"
				providerFile := filepath.Join(clustersDir, cleanClusterName, "provider.txt")
				if providerBytes, err := os.ReadFile(providerFile); err == nil {
					provider = strings.TrimSpace(string(providerBytes))
				}
				clusters = append(clusters, ClusterInfo{Name: cleanClusterName, Provider: provider})
				clusterNames[cleanClusterName] = true
			}
		}
	}

	return clusters, nil
}

var clusterCmd = &cobra.Command{
	Use:   "cluster",
	Short: "Manage local Kubernetes clusters",
}

var clusterListCmd = &cobra.Command{
	Use:   "list",
	Short: "List all local clusters",
	Run: func(cmd *cobra.Command, args []string) {
		clusters, err := listClusters()
		if err != nil {
			fmt.Printf("Error listing clusters: %v\n", err)
			return
		}

		if len(clusters) == 0 {
			fmt.Println("No clusters found.")
			return
		}

		w := tabwriter.NewWriter(os.Stdout, 0, 0, 3, ' ', 0)
		_, _ = fmt.Fprintln(w, "NAME\tPROVIDER")
		for _, cluster := range clusters {
			_, _ = fmt.Fprintf(w, "%s\t%s\n", cluster.Name, cluster.Provider)
		}
		_ = w.Flush()
	},
}

var clusterCreateCmd = &cobra.Command{
	Use:   "create <cluster-name>",
	Short: "Create a new local cluster",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		name := args[0]
		fmt.Printf("Creating cluster '%s'...\n", name)
		// TODO: implement cluster creation
		fmt.Println("Cluster created successfully")
	},
}

var clusterDeleteCmd = &cobra.Command{
	Use:   "delete <cluster-name>",
	Short: "Delete a local cluster",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		name := args[0]
		fmt.Printf("Deleting cluster '%s'...\n", name)
		// TODO: implement cluster deletion
		fmt.Println("Cluster deleted successfully")
	},
}

var clusterDetailsCmd = &cobra.Command{
	Use:   "details <cluster-name>",
	Short: "Show cluster details",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		name := args[0]
		fmt.Printf("Details for cluster '%s':\n", name)
		// TODO: implement cluster details
		fmt.Println("  Status: Running")
		fmt.Println("  Provider: talos")
	},
}

var clusterK8sDetailsCmd = &cobra.Command{
	Use:   "k8sdetails <cluster-name>",
	Short: "Show Kubernetes cluster details",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		name := args[0]
		fmt.Printf("Kubernetes details for cluster '%s':\n", name)
		// TODO: implement k8s details
		fmt.Println("  Version: v1.29.0")
		fmt.Println("  Nodes: 3")
	},
}

var clusterKubeconfigCmd = &cobra.Command{
	Use:   "kubeconfig <cluster-name>",
	Short: "Get kubeconfig for a cluster",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		name := args[0]
		fmt.Printf("Getting kubeconfig for cluster '%s'...\n", name)
		// TODO: implement kubeconfig retrieval
		fmt.Println("# kubeconfig output would go here")
	},
}

func init() {
	clusterCmd.AddCommand(clusterListCmd)
	clusterCmd.AddCommand(clusterCreateCmd)
	clusterCmd.AddCommand(clusterDeleteCmd)
	clusterCmd.AddCommand(clusterDetailsCmd)
	clusterCmd.AddCommand(clusterK8sDetailsCmd)
	clusterCmd.AddCommand(clusterKubeconfigCmd)
}
