package config

import (
	"errors"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

type Config struct {
	Provider string `yaml:"provider"`
}

var (
	configFile string
)

// Init ensures config exists; creates with defaults if missing.
func Init() error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	dir := filepath.Join(home, ".k8slocal")
	if err := os.MkdirAll(dir, 0o750); err != nil {
		return err
	}
	configFile = filepath.Join(dir, "config.yaml")
	if _, err := os.Stat(configFile); errors.Is(err, os.ErrNotExist) {
		def := &Config{Provider: "talos"}
		return Save(def)
	}
	return nil
}

// Get loads current config.
func Get() (*Config, error) {
	b, err := os.ReadFile(configFile) // #nosec G304 -- configFile is constructed from user home dir, which is expected
	if err != nil {
		return nil, err
	}
	var c Config
	if err := yaml.Unmarshal(b, &c); err != nil {
		return nil, err
	}
	// Fallback if file missing provider
	if c.Provider == "" {
		c.Provider = "talos"
	}
	return &c, nil
}

// Save writes config atomically.
func Save(c *Config) error {
	tmp := configFile + ".tmp"
	b, err := yaml.Marshal(c)
	if err != nil {
		return err
	}
	if err := os.WriteFile(tmp, b, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, configFile)
}
