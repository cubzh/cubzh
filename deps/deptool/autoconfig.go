package deptool

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/voxowl/objectstorage"
)

type Config struct {
	Deps map[string]string `json:"Deps"`
}

func parseConfig(configFilePath string) (Config, error) {

	configData, err := os.ReadFile(configFilePath)
	if err != nil {
		return Config{}, fmt.Errorf("failed to read config file: %w", err)
	}

	var config Config
	err = json.Unmarshal(configData, &config)
	if err != nil {
		return Config{}, fmt.Errorf("failed to parse config file: %w", err)
	}

	return config, nil
}

func Autoconfigure(objectStorage objectstorage.ObjectStorage, depsDirPath, configFilePath string, platforms []string) error {

	if configFilePath == "" {
		return fmt.Errorf("config file path is required")
	}

	// parse config file
	config, err := parseConfig(configFilePath)
	if err != nil {
		return fmt.Errorf("failed to parse config file: %w", err)
	}

	// get object storage credentials

	// for each dependency, download the dependency
	for depName, depVersion := range config.Deps {
		// fmt.Printf("⚙️ downloading dependency (%s|%s)\n", depName, depVersion)
		force := false
		for _, platform := range platforms {
			err = DownloadArtifacts(objectStorage, depsDirPath, depName, depVersion, platform, force)
			if err != nil {
				return fmt.Errorf("failed to download dependency (%s|%s): %w", depName, depVersion, err)
			}
		}
	}

	// for each dependency, activate the dependency version
	for depName, depVersion := range config.Deps {
		// fmt.Printf("⚙️ activating dependency (%s|%s)\n", depName, depVersion)
		err = ActivateDependency(depsDirPath, depName, depVersion)
		if err != nil {
			return fmt.Errorf("failed to activate dependency (%s|%s): %w", depName, depVersion, err)
		}
	}

	return nil
}
