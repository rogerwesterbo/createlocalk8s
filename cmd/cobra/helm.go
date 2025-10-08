package cobra

import (
	"fmt"

	"github.com/spf13/cobra"
)

var helmCmd = &cobra.Command{
	Use:   "helm",
	Short: "Manage Helm releases",
}

var helmListCmd = &cobra.Command{
	Use:   "list <cluster-name>",
	Short: "List Helm releases in a cluster",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		name := args[0]
		fmt.Printf("Helm releases in cluster '%s':\n", name)
		// TODO: implement helm list
		fmt.Println("No releases found")
	},
}

func init() {
	helmCmd.AddCommand(helmListCmd)
}
