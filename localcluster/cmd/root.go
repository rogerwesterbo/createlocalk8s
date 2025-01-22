package cmd

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path"
	"runtime"

	homedir "github.com/mitchellh/go-homedir"
	"github.com/rogerwesterbo/createlocalk8s/localcluster/models"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var (
	cfgFile     string
	projectBase string
	userLicense string
	clusterType models.ClusterType
)

// ror-config defaults
var defaults = models.CliConfig{
	LogLevel:    "info",
	ClusterType: models.ClusterTypeKind,
}

var rootCmd = &cobra.Command{
	Use:   "localcluster",
	Short: "LocalCluster CLI",
	Long:  `LocalCluster is a CLI to create and manage local kubernetes clusters.`,
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("Current Cluster type: %v\n", viper.GetString("clusterType"))
	},
	PreRunE: func(cmd *cobra.Command, args []string) error {
		if len(args) == 0 {
			_ = cmd.Help()
			return nil
		}
		return nil
	},
}

func init() {
	cobra.OnInitialize(initConfig)
	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.localcluster.yaml)")
	rootCmd.PersistentFlags().StringVarP(&projectBase, "projectbase", "b", "", "base project directory eg. github.com/spf13/")
	rootCmd.PersistentFlags().StringVarP(&userLicense, "license", "l", "", "Name of license for the project (can provide `licensetext` in config)")
	rootCmd.PersistentFlags().String("clustertype", string(models.ClusterTypeKind), "Use Viper for configuration")

	viper.BindPFlag("clusterType", rootCmd.PersistentFlags().Lookup("clustertype"))
	viper.BindPFlag("useViper", rootCmd.PersistentFlags().Lookup("viper"))
}

func initConfig() {
	// Don't forget to read config either from cfgFile or from home directory!
	if cfgFile != "" {
		// Use config file from the flag.
		viper.SetConfigFile(cfgFile)
	} else {
		// Find home directory.
		home, err := homedir.Dir()
		if err != nil {
			fmt.Println(err)
			os.Exit(1)
		}

		// Search config in home directory with name ".cobra" (without extension).
		viper.AddConfigPath(home)
		viper.SetConfigType("yaml")
		viper.SetConfigName(".localcluster")

		configFullPath := path.Join(home, ".localcluster.yaml")

		info, err := os.Stat(configFullPath)
		if errors.Is(err, os.ErrNotExist) {
			CreateDefaultConfigFile()
			info, err = os.Stat(configFullPath)
			if err != nil {
				_, _ = fmt.Fprintln(os.Stderr, "cannot read config file", err)
				os.Exit(1)
			}
		}
		if info.Mode() != 0600 && runtime.GOOS != "windows" {
			_, _ = fmt.Fprintln(os.Stderr, "config file does not have strict enough permissions, wont allow persisting of privileged credentials")
			os.Exit(1)
		}
	}

	if err := viper.ReadInConfig(); err != nil {
		fmt.Println("Can't read config:", err)
		os.Exit(1)
	}
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

// CreateDefaultConfigFile creates a new, or overwrites an old config file
func CreateDefaultConfigFile() {
	home, err := homedir.Dir()
	if err != nil {
		cobra.CheckErr(err)
	}
	configDirPath := home
	configFullPath := path.Join(home, ".localcluster.yaml")

	_ = os.MkdirAll(configDirPath, os.ModePerm)

	config := defaults

	configBytes, err := json.Marshal(config)
	cobra.CheckErr(err)

	_ = viper.ReadConfig(bytes.NewBuffer(configBytes))

	err = viper.WriteConfigAs(configFullPath)
	cobra.CheckErr(err)

	err = os.Chmod(configFullPath, 0600)
	cobra.CheckErr(err)
}
