package deptool

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/voxowl/objectstorage"
)

// DownloadArtifacts downloads artifacts from object storage to the local filesystem
func DownloadArtifacts(objectStorage objectstorage.ObjectStorage, depsDirPath, depName, version, platform string, forceFlag bool) error {
	fmt.Printf("⭐️ Downloading artifacts for [%s] [%s] [%s] (force: %t)\n", depName, version, platform, forceFlag)

	// Validate arguments
	if objectStorage == nil {
		return fmt.Errorf("object storage client is nil")
	}

	if !isDependencyNameValid(depName) {
		return fmt.Errorf("invalid dependency name: %s", depName)
	}

	if !isPlatformNameValid(platform) {
		return fmt.Errorf("invalid platform name: %s", platform)
	}

	if version == "" {
		return fmt.Errorf("version is required")
	}

	// Destination directory path
	destinationDirPath := filepath.Join(depsDirPath, constructDepArtifactsPath(depName, version, platform))

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

	// Construct the S3 key prefix
	s3KeyPrefix := fmt.Sprintf("%s/%s/%s/", depName, version, platform)

	// List objects in the platform prefix
	keys, err := objectStorage.List(s3KeyPrefix, objectstorage.ListOpts{})
	if err != nil {
		return err
	}

	for _, key := range keys {
		// Download the object at key
		objectContent, err := objectStorage.Download(key)
		if err != nil {
			return err
		}
		defer objectContent.Close()

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

		// Create the file
		file, err := os.Create(localFilePath)
		if err != nil {
			return fmt.Errorf("failed to create local file %s: %s", localFilePath, err.Error())
		}
		defer file.Close()

		// Copy the data to the file
		if _, err := io.Copy(file, objectContent); err != nil {
			return fmt.Errorf("failed to write to local file %s: %s", localFilePath, err.Error())
		}
	}

	return nil // no error
}
