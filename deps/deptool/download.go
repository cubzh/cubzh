package main

import (
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/voxowl/objectstorage"
)

// DownloadArtifacts downloads artifacts from object storage to the local filesystem
func downloadArtifacts(depName, version, platform string, forceFlag bool) error {
	fmt.Printf("⭐️ Downloading artifacts for [%s] [%s] [%s] (force: %t)\n", depName, version, platform, forceFlag)

	// Validate arguments
	if !slices.Contains(supportedDependencies, depName) {
		return fmt.Errorf("invalid dependency name: %s", depName)
	}

	if platform != PlatformAll && !slices.Contains(supportedPlatforms, platform) {
		return fmt.Errorf("invalid platform name: %s", platform)
	}

	if version == "" {
		return fmt.Errorf("version is required")
	}

	// Destination directory path
	depsDirPath := filepath.Join("..", "..", "deps")
	destinationDirPath := filepath.Join(depsDirPath, constructDepArtifactsPathNew(depName, version, platform))

	// If the destination directory exists, and --force is not set, prints a message and exits
	if _, err := os.Stat(destinationDirPath); err == nil {
		if !forceFlag {
			fmt.Printf("✅ Artifacts appear to be already present locally. Doing nothing.\n(%s)\n", destinationDirPath)
			fmt.Println("Note: You can use --force to force download the artifacts")
			return nil
		}
		// Destination directory exists, and --force is set, so we delete it
		if err := os.RemoveAll(destinationDirPath); err != nil {
			return fmt.Errorf("failed to delete destination directory: %w", err)
		}
	}

	// Create the object storage client
	objectStorageClient, err := getObjectStorageClient()
	if err != nil {
		return err
	}

	// Construct the S3 key prefix
	s3KeyPrefix := fmt.Sprintf("%s/%s/%s/", depName, version, platform)

	// List objects in the platform prefix
	keys, err := objectStorageClient.List(s3KeyPrefix, objectstorage.ListOpts{})
	if err != nil {
		return err
	}

	for _, key := range keys {
		// Download the object at key
		data, err := objectStorageClient.Download(key)
		if err != nil {
			return err
		}

		// add "prebuilt" element to the key, after the 2nd element
		keyWithPrebuiltElement := ""
		{
			// Split the key into parts
			parts := strings.Split(key, "/") // keys always have "/" separators
			if len(parts) < 4 {
				return fmt.Errorf("invalid key format: %s", key)
			}
			// Insert "prebuilt" after the second element
			newParts := append(parts[:2], append([]string{"prebuilt"}, parts[2:]...)...)
			// Join back into a path
			keyWithPrebuiltElement = strings.Join(newParts, "/")
		}

		// Construct the local file path (must use correct path separator)
		localFilePath := filepath.Join(depsDirPath, filepath.FromSlash(keyWithPrebuiltElement))
		fmt.Println("📝 writing:", localFilePath)

		// Create any necessary subdirectories
		if err := os.MkdirAll(filepath.Dir(localFilePath), 0755); err != nil {
			return fmt.Errorf("failed to create directories for %s: %s", localFilePath, err.Error())
		}

		// Write the data to the file
		if err := os.WriteFile(localFilePath, data, 0644); err != nil {
			return fmt.Errorf("failed to write to local file %s: %s", localFilePath, err.Error())
		}
	}

	return nil // no error
}
