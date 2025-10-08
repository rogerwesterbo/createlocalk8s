package cobra

import (
	"fmt"
	"os"

	cfgpkg "github.com/rogerwesterbo/createlocalk8s/internal/config"
	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "k8slocal",
	Short: "Create and manage local Kubernetes clusters",
	// When no subcommand/args: show help.
	Run: func(cmd *cobra.Command, args []string) {
		if err := cmd.Help(); err != nil {
			fmt.Fprintf(os.Stderr, "Error displaying help: %v\n", err)
		}
	},
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}

func init() {
	if cfg, err := cfgpkg.LoadOrInit(); err != nil {
		if _, printErr := fmt.Fprintf(os.Stderr, "failed initializing config: %v\n", err); printErr != nil {
			panic(printErr)
		}
		os.Exit(1)
	} else {
		// Put current provider into extended description.
		rootCmd.Long = fmt.Sprintf(
			"Create and manage local Kubernetes clusters.\n\nCurrent provider: %s",
			cfg.Provider,
		)
	}

	// Minimal custom help template.
	rootCmd.SetHelpTemplate(`{{with (or .Long .Short)}}{{. | trimTrailingWhitespaces}}{{end}}

Usage:
  {{.UseLine}}
{{if .HasAvailableSubCommands}}
Available Commands:{{range .Commands}}{{if (or .IsAvailableCommand (eq .Name "help"))}}
  {{rpad .Name .NamePadding }} {{.Short}}{{end}}{{end}}{{end}}
{{if .HasAvailableLocalFlags}}
Flags:
{{.LocalFlags.FlagUsages | trimTrailingWhitespaces}}{{end}}
{{if .HasAvailableSubCommands}}
Use "{{.CommandPath}} [command] --help" for more information about a command.{{end}}
`)

	// Register subcommands
	rootCmd.AddCommand(clusterCmd)
	rootCmd.AddCommand(providerCmd)
	rootCmd.AddCommand(appsCmd)
	rootCmd.AddCommand(helmCmd)
}
