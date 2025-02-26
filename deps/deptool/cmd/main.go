package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/cubzh/cubzh/deps/deptool"
	"github.com/spf13/cobra"
)

const (
	// Object storage credentials (env var names)
	digitalOceanSpacesAuthKeyEnvVar    = "CUBZH_DIGITALOCEAN_SPACES_AUTH_KEY"
	digitalOceanSpacesAuthSecretEnvVar = "CUBZH_DIGITALOCEAN_SPACES_AUTH_SECRET"
	// Name of the symlink to the active dependency version
	ACTIVE_DEPENDENCY_SYMLINK_NAME = "_active_"
)

func main() {

	var rootCmd = &cobra.Command{
		Use:     "deps",
		Short:   "Dependencies management tool for Cubzh",
		Long:    `A CLI tool to manage dependencies for Cubzh, including uploading prebuilt artifacts to Object Storage.`,
		Version: "0.0.2",
	}

	// deptool upload
	{
		var uploadCmd = &cobra.Command{
			Use:   "upload <dependency> <version> <platform>",
			Short: "Upload prebuilt dependency artifacts to Object Storage",
			Args:  cobra.ExactArgs(3),
			RunE:  uploadCmdFunc,
		}
		rootCmd.AddCommand(uploadCmd)
	}

	// deptool download
	{
		var downloadCmd = &cobra.Command{
			Use:   "download [-f --force] <dependency> <version> <platform>",
			Short: "Download prebuilt dependency artifacts from Object Storage",
			Args:  cobra.ExactArgs(3),
			RunE:  downloadCmdFunc,
		}
		downloadCmd.Flags().BoolP("force", "f", false, "Force download even if files already exist locally")
		rootCmd.AddCommand(downloadCmd)
	}

	// deptool activate
	{
		var activateCmd = &cobra.Command{
			Use:   "activate <dependency> <version>",
			Short: "Activate a version of dependency",
			Args:  cobra.ExactArgs(2),
			RunE:  activateCmdFunc,
		}
		rootCmd.AddCommand(activateCmd)
	}

	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

// Command functions

// deptool upload <dependency> <version> <platform>
// example: deptool upload libluau 0.661 macos
func uploadCmdFunc(cmd *cobra.Command, args []string) error {
	depName := args[0]
	version := args[1]
	platform := args[2]

	// construct object storage client opts
	opts := deptool.DigitalOceanObjectStorageClientOpts{}
	authKey, authSecret, err := getObjectStorageCredentialsFromEnvVars()
	if err == nil {
		opts.AuthKey = authKey
		opts.AuthSecret = authSecret
	}

	// construct object storage client
	objectStorage, err := deptool.NewDigitalOceanObjectStorageClient(opts)
	if err != nil {
		return err
	}

	// find git repo root directory
	gitRepoRootDir, err := findPathToFirstParentGitRepo()
	if err != nil {
		return err
	}

	// construct path to deps directory
	depsDirPath := filepath.Join(gitRepoRootDir, "deps")

	return deptool.UploadArtifacts(objectStorage, depsDirPath, depName, version, platform)
}

// deptool download <dependency> <version> <platform>
// example: deptool download libluau 0.661 macos
func downloadCmdFunc(cmd *cobra.Command, args []string) error {
	depName := args[0]
	version := args[1]
	platform := args[2]
	forceFlag, err := cmd.Flags().GetBool("force")
	if err != nil {
		return err
	}

	// construct object storage client opts
	opts := deptool.DigitalOceanObjectStorageClientOpts{}
	authKey, authSecret, err := getObjectStorageCredentialsFromEnvVars()
	if err == nil {
		opts.AuthKey = authKey
		opts.AuthSecret = authSecret
	}

	// construct object storage client
	objectStorage, err := deptool.NewDigitalOceanObjectStorageClient(opts)
	if err != nil {
		return err
	}

	// find git repo root directory
	gitRepoRootDir, err := findPathToFirstParentGitRepo()
	if err != nil {
		return err
	}

	// construct path to deps directory
	depsDirPath := filepath.Join(gitRepoRootDir, "deps")

	return deptool.DownloadArtifacts(objectStorage, depsDirPath, depName, version, platform, forceFlag)
}

// deptool upload <dependency> <version> <platform>
// example: deptool upload libluau 0.661 macos
func activateCmdFunc(cmd *cobra.Command, args []string) error {
	depName := args[0]
	version := args[1]

	gitRepoRootDir, err := findPathToFirstParentGitRepo()
	if err != nil {
		return err
	}

	// path to dependency directory wanted to be activated
	depDirPath := filepath.Join(gitRepoRootDir, "deps", depName)
	depVersionDirPath := filepath.Join(depDirPath, version)

	fmt.Printf("🔍 trying to activate dependency [%s] version [%s]\n", depName, version)

	// check if the dependency directory exists
	if _, err := os.Stat(depDirPath); os.IsNotExist(err) {
		return fmt.Errorf("dependency directory doesn't exist: %s", depDirPath)
	}

	// check if the dependency version directory exists
	if _, err := os.Stat(depVersionDirPath); os.IsNotExist(err) {
		// TODO: try to download the dependency
		return fmt.Errorf("dependency version directory doesn't exist: %s", depVersionDirPath)
	}

	symlinkPath := filepath.Join(depDirPath, ACTIVE_DEPENDENCY_SYMLINK_NAME)

	// remove existing symlink if it exists
	if _, err := os.Stat(symlinkPath); err == nil {
		os.Remove(symlinkPath)
	}

	// create a directory symlink to the dependency version
	err = os.Symlink(depVersionDirPath, symlinkPath)
	if err != nil {
		return fmt.Errorf("failed to create symlink: %w", err)
	}

	return nil
}

//
// utility functions
//

func getObjectStorageCredentialsFromEnvVars() (string, string, error) {
	authKey := os.Getenv(digitalOceanSpacesAuthKeyEnvVar)
	authSecret := os.Getenv(digitalOceanSpacesAuthSecretEnvVar)
	if authKey == "" || authSecret == "" {
		return "", "", fmt.Errorf("missing digital ocean spaces auth key or secret")
	}
	return authKey, authSecret, nil
}

// findPathToFirstParentGitRepo finds the path to the first parent git repository
// starting from the current working directory.
// Returns an error if no git repository is found after <limit> iterations.
func findPathToFirstParentGitRepo() (string, error) {
	limit := 20

	// get current working directory
	dir, err := os.Getwd()
	if err != nil {
		return "", err
	}

	// Find the first parent directory that is a git repository
	// fmt.Println("🔍 searching for git repo in:", dir)
	for dir != "." {
		if _, err := os.Stat(filepath.Join(dir, ".git")); err == nil {
			// fmt.Println("✅ found git repo in:", dir)
			return dir, nil
		}
		dir = filepath.Dir(dir)
		limit--
		if limit <= 0 {
			return "", fmt.Errorf("no git repository found")
		}
	}
	return "", fmt.Errorf("no git repository found")
}
