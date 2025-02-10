package main

import (
	"fmt"
	"path/filepath"
)

func UploadArtifacts(depName, depVersion, platform string) error {

	// deps/<depName>/<depVersion>/prebuilt/<platform>
	// deps/luau/0.693/prebuilt/macos/arm64/include
	// deps/luau/0.693/prebuilt/macos/arm64/lib

	depPath := filepath.Join("deps", depName, depVersion, "prebuilt", platform)

	fmt.Printf("Uploading artifacts for %s %s %s\n", depName, depVersion, platform)
	fmt.Printf("depPath: %s\n", depPath)

	// Create the object storage client
	objectStorageClient, err := getObjectStorageClient()
	if err != nil {
		return err
	}

	fmt.Println("Debug.", objectStorageClient)

	// // Make sure the dependency name exists
	// if _, err := os.Stat(depPath); os.IsNotExist(err) {
	// 	return fmt.Errorf("dependency not found : %s", depPath)
	// }

	// // Make sure the dependency version exists
	// if _, err := os.Stat(depVersionPath); os.IsNotExist(err) {
	// 	return fmt.Errorf("dependency version not found : %s", depVersionPath)
	// }

	// // Make sure the platform exists
	// if _, err := os.Stat(platformPath); os.IsNotExist(err) {
	// 	return fmt.Errorf("<dependency>/prebuilt/<platform> path does not exist: %s", platformPath)
	// }

	// // Read files to upload

	// directoriesToUpload := []string{"lib", "include"}

	// for _, directoryToUpload := range directoriesToUpload {
	// 	artifactsPath := filepath.Join(platformPath, directoryToUpload)

	// 	// Verify the artifacts directory exists
	// 	if _, err := os.Stat(artifactsPath); os.IsNotExist(err) {
	// 		return fmt.Errorf("artifacts directory does not exist: %s", artifactsPath)
	// 	}

	// 	// Walk through the artifacts directory
	// 	err = filepath.Walk(artifactsPath, func(path string, info os.FileInfo, err error) error {
	// 		if err != nil {
	// 			return err
	// 		}

	// 		// Skip directories
	// 		if info.IsDir() {
	// 			return nil
	// 		}

	// 		// Open the file
	// 		file, err := os.Open(path)
	// 		if err != nil {
	// 			return fmt.Errorf("failed to open file %s: %w", path, err)
	// 		}
	// 		defer file.Close()

	// 		// Create S3 key based on platform and relative path
	// 		relPath, err := filepath.Rel(artifactsPath, path)
	// 		if err != nil {
	// 			return fmt.Errorf("failed to get relative path: %w", err)
	// 		}
	// 		objectStorageKey := filepath.Join(platform, relPath)

	// 		// Upload the file to object storage
	// 		err = objectStorageClient.Upload(objectStorageKey, file)
	// 		if err != nil {
	// 			return fmt.Errorf("failed to upload file %s: %w", path, err)
	// 		}

	// 		return nil
	// 	})
	// }

	return err
}
