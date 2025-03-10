package deptool

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func UploadArtifacts(objectStorageBuildFunc ObjectStorageBuildFunc, depsDirPath, depName, version, platform string) error {
	fmt.Printf("⭐️ Uploading artifacts for [%s] [%s] [%s]\n", depName, version, platform)

	var err error

	// Validate arguments

	if !isDependencyNameValid(depName) {
		return fmt.Errorf("invalid dependency name: %s", depName)
	}

	if !isPlatformNameValid(platform) {
		return fmt.Errorf("invalid platform name: %s", platform)
	}

	if version == "" {
		return fmt.Errorf("version is required")
	}

	// Construct the list of artifacts paths to upload
	depsPathsToUpload := []string{}
	if platform == PlatformAll {
		for _, supportedPlatform := range supportedPlatforms {
			depsPathsToUpload = append(depsPathsToUpload, constructDepArtifactsPath(depName, version, supportedPlatform))
		}
	} else {
		depsPathsToUpload = append(depsPathsToUpload, constructDepArtifactsPath(depName, version, platform))
	}

	objectStorage, err := objectStorageBuildFunc()
	if err != nil {
		return fmt.Errorf("failed to build object storage client: %w", err)
	}

	// Try to upload each path
	for _, depPath := range depsPathsToUpload {
		depPath = filepath.Join(depsDirPath, depPath)

		// Make sure the dependency name exists
		if _, err := os.Stat(depPath); os.IsNotExist(err) {
			fmt.Printf("-> Path does not exist. Skipping. %s\n", depPath)
			continue
		}

		// Read all files and upload them
		err = filepath.Walk(depPath, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}

			// Skip directories
			if info.IsDir() {
				return nil
			}

			// Open the file
			file, err := os.Open(path)
			if err != nil {
				return fmt.Errorf("failed to open file %s: %w", path, err)
			}
			defer file.Close()

			// Create S3 key based on platform and relative path
			objectStorageKey, err := filepath.Rel(depsDirPath, path)
			if err != nil {
				return fmt.Errorf("failed to get relative path: %w", err)
			}

			// Enforce / separator (even on Windows)
			objectStorageKey = strings.ReplaceAll(objectStorageKey, `\`, `/`)

			// Split path into elements and remove "prebuilt" if it's the 3rd element
			pathElements := strings.Split(objectStorageKey, "/")
			if len(pathElements) >= 3 && pathElements[2] == "prebuilt" {
				pathElements = append(pathElements[:2], pathElements[3:]...)
				objectStorageKey = strings.Join(pathElements, "/")
			}

			// If last element is ".DS_Store", skip
			if pathElements[len(pathElements)-1] == ".DS_Store" {
				return nil
			}

			fmt.Printf("  🔥 Uploading file: %s\n", objectStorageKey)

			// Upload the file to object storage
			err = objectStorage.Upload(objectStorageKey, file)
			if err != nil {
				return fmt.Errorf("failed to upload file %s: %w", path, err)
			}

			return nil
		})

		if err != nil {
			fmt.Printf("❌ failed to upload files (%s): %s\n", depPath, err.Error())
			return err
		}
	}

	fmt.Println("✅ Successfully uploaded all files")
	return nil
}
