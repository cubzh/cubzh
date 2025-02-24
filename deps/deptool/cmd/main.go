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
)

func main() {

	// get path of the executable
	executablePath, err := os.Executable()
	if err != nil {
		fmt.Println("failed to get executable path:", err)
		os.Exit(1)
	}
	fmt.Println("executable path:", executablePath)

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
// returns an error if no git repository is found
func findPathToFirstParentGitRepo() (string, error) {
	limit := 100
	// Find the first parent directory that is a git repository
	dir, err := filepath.Abs(filepath.Dir(os.Args[0]))
	if err != nil {
		return "", err
	}
	// fmt.Println("🔍 searching for git repo in:", dir)
	for dir != "." {
		if _, err := os.Stat(filepath.Join(dir, ".git")); err == nil {
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
