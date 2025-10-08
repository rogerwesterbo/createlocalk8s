package config

import (
	"errors"
	"os"
	"path/filepath"

	"github.com/spf13/viper"
	"gopkg.in/yaml.v3"
)

type Config struct {
	Provider string `yaml:"provider"`
}

var (
	configFile string
	loaded     *Config
)

// LoadOrInit loads YAML, creates defaults if absent, and syncs into viper.
func LoadOrInit() (*Config, error) {
	if loaded != nil {
		return loaded, nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, err
	}
	dir := filepath.Join(home, ".k8slocal")
	if err := os.MkdirAll(dir, 0o750); err != nil {
		return nil, err
	}
	configFile = filepath.Join(dir, "config.yaml")

	if _, err := os.Stat(configFile); errors.Is(err, os.ErrNotExist) {
		loaded = &Config{Provider: "talos"}
		if err := Save(loaded); err != nil {
			return nil, err
		}
		syncToViper(loaded)
		return loaded, nil
	}

	data, err := os.ReadFile(configFile) // #nosec G304 -- configFile is constructed from user home dir, which is expected
	if err != nil {
		return nil, err
	}
	var c Config
	if err := yaml.Unmarshal(data, &c); err != nil {
		return nil, err
	}
	if c.Provider == "" {
		c.Provider = "talos"
		_ = Save(&c)
	}
	loaded = &c
	syncToViper(loaded)
	return loaded, nil
}

// Get convenience wrapper.
func Get() (*Config, error) {
	return LoadOrInit()
}

// Save persists and updates viper.
func Save(c *Config) error {
	if configFile == "" {
		if _, err := LoadOrInit(); err != nil {
			return err
		}
	}
	tmp := configFile + ".tmp"
	b, err := yaml.Marshal(c)
	if err != nil {
		return err
	}
	if err := os.WriteFile(tmp, b, 0o600); err != nil {
		return err
	}
	if err := os.Rename(tmp, configFile); err != nil {
		return err
	}
	loaded = c
	syncToViper(c)
	return nil
}

func syncToViper(c *Config) {
	viper.Set("provider", c.Provider)
}

// Provider helper (reads from loaded struct; ensures init).
func Provider() string {
	if loaded == nil {
		if _, err := LoadOrInit(); err != nil {
			return ""
		}
	}
	return loaded.Provider
}
