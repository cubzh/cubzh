package main

import (
	"errors"
	"fmt"
)

// DownloadArtifacts downloads artifacts from object storage to the local filesystem
func DownloadArtifacts(platform string, destinationPath string) error {

	// Create the object storage client
	objectStorageClient, err := getObjectStorageClient()
	if err != nil {
		return err
	}

	fmt.Println(objectStorageClient)

	// // Create the destination directory if it doesn't exist
	// if err := os.MkdirAll(destinationPath, 0755); err != nil {
	// 	return fmt.Errorf("failed to create destination directory: %w", err)
	// }

	// // List objects in the platform prefix
	// paginator := s3.NewListObjectsV2Paginator(c.client, &s3.ListObjectsV2Input{
	// 	Bucket: aws.String(c.bucketName),
	// 	Prefix: aws.String(platform + "/"),
	// })

	// for paginator.HasMorePages() {
	// 	page, err := paginator.NextPage(ctx)
	// 	if err != nil {
	// 		return fmt.Errorf("failed to list objects: %w", err)
	// 	}

	// 	for _, obj := range page.Contents {
	// 		// Create the full local path
	// 		localPath := filepath.Join(destinationPath, filepath.Base(*obj.Key))

	// 		// Create any necessary subdirectories
	// 		if err := os.MkdirAll(filepath.Dir(localPath), 0755); err != nil {
	// 			return fmt.Errorf("failed to create directories for %s: %w", localPath, err)
	// 		}

	// 		// Download the object
	// 		result, err := c.client.GetObject(ctx, &s3.GetObjectInput{
	// 			Bucket: aws.String(c.bucketName),
	// 			Key:    obj.Key,
	// 		})
	// 		if err != nil {
	// 			return fmt.Errorf("failed to download object %s: %w", *obj.Key, err)
	// 		}

	// 		// Create the local file
	// 		file, err := os.Create(localPath)
	// 		if err != nil {
	// 			return fmt.Errorf("failed to create local file %s: %w", localPath, err)
	// 		}

	// 		// Copy the content
	// 		if _, err = io.Copy(file, result.Body); err != nil {
	// 			file.Close()
	// 			return fmt.Errorf("failed to write to local file %s: %w", localPath, err)
	// 		}

	// 		file.Close()
	// 		result.Body.Close()
	// 	}
	// }

	return errors.New("not implemented")
}
