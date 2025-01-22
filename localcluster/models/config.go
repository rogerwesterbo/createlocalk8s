package models

type ClusterType string

const (
	ClusterTypeKind ClusterType = "kind"
	ClusterTypeK0s  ClusterType = "k0s"
	ClusterTypeK3s  ClusterType = "k3s"
)

type CliConfig struct {
	LogLevel    string      `json:"logLevel"`
	ClusterType ClusterType `json:"clusterType"`
}
