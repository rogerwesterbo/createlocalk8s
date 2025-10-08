package cobra

import (
	"fmt"

	"github.com/spf13/cobra"
)

var appsCmd = &cobra.Command{
	Use:   "apps",
	Short: "Manage cluster applications",
}

var appsListCmd = &cobra.Command{
	Use:   "list <cluster-name>",
	Short: "List applications installed in a cluster",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		name := args[0]
		fmt.Printf("Applications in cluster '%s':\n", name)
		// TODO: implement apps listing
		fmt.Println("No applications found")
	},
}

func init() {
	appsCmd.AddCommand(appsListCmd)
}
