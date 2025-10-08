package cobra

import (
	"fmt"
	"os"

	cfgpkg "github.com/rogerwesterbo/createlocalk8s/internal/config"
	"github.com/spf13/cobra"
)

var providerCmd = &cobra.Command{
	Use:   "provider",
	Short: "Manage cluster providers",
}

var providerListCmd = &cobra.Command{
	Use:   "list",
	Short: "List available providers",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("Available providers:")
		providers := []string{"talos", "kind", "k3s", "minikube"}
		cfg, err := cfgpkg.Get()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error loading config: %v\n", err)
			os.Exit(1)
		}
		for _, p := range providers {
			current := ""
			if cfg != nil && p == cfg.Provider {
				current = " (current)"
			}
			fmt.Printf("  - %s%s\n", p, current)
		}
	},
}

var providerSetCmd = &cobra.Command{
	Use:   "set <provider>",
	Short: "Set the default provider",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		provider := args[0]
		cfg, err := cfgpkg.Get()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error loading config: %v\n", err)
			os.Exit(1)
		}
		cfg.Provider = provider
		if err := cfgpkg.Save(cfg); err != nil {
			fmt.Fprintf(os.Stderr, "Error saving config: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("Provider set to: %s\n", provider)
	},
}

func init() {
	providerCmd.AddCommand(providerListCmd)
	providerCmd.AddCommand(providerSetCmd)
}
