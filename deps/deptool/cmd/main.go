package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/cubzh/cubzh/deps/deptool"
	"github.com/spf13/cobra"
	"github.com/voxowl/objectstorage"
)

const (
	// Object storage credentials (env var names)
	digitalOceanSpacesAuthKeyEnvVar    = "CUBZH_DIGITALOCEAN_SPACES_AUTH_KEY"
	digitalOceanSpacesAuthSecretEnvVar = "CUBZH_DIGITALOCEAN_SPACES_AUTH_SECRET"
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

	// deptool autoconfig
	{
		var autoconfigCmd = &cobra.Command{
			Use:   "autoconfig <platform> [<cubzh repo root dir path>]",
			Short: "Autoconfigure the dependencies",
			Args:  cobra.RangeArgs(1, 2),
			RunE:  autoconfigCmdFunc,
		}
		rootCmd.AddCommand(autoconfigCmd)
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

	// find git repo root directory
	gitRepoRootDir, err := findPathToFirstParentGitRepo()
	if err != nil {
		return err
	}

	// construct path to deps directory
	depsDirPath := filepath.Join(gitRepoRootDir, "deps")

	return deptool.UploadArtifacts(objectStorageBuildFunc, depsDirPath, depName, version, platform)
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

	// find git repo root directory
	gitRepoRootDir, err := findPathToFirstParentGitRepo()
	if err != nil {
		return err
	}

	// construct path to deps directory
	depsDirPath := filepath.Join(gitRepoRootDir, "deps")

	return deptool.DownloadArtifacts(objectStorageBuildFunc, depsDirPath, depName, version, platform, forceFlag)
}

// deptool upload <dependency> <version> <platform>
// example: deptool upload libluau 0.661 macos
func activateCmdFunc(cmd *cobra.Command, args []string) error {
	depName := args[0]
	version := args[1]

	// find git repo root directory
	gitRepoRootDir, err := findPathToFirstParentGitRepo()
	if err != nil {
		return err
	}

	depsDirPath := filepath.Join(gitRepoRootDir, "deps")

	return deptool.ActivateDependency(depsDirPath, depName, version)
}

// deptool autoconfig platforms [<cubzh repo root dir path>]
// example: deptool autoconfig macos,ios,android,windows,linux
func autoconfigCmdFunc(cmd *cobra.Command, args []string) error {
	platforms := []string{}
	if len(args) > 0 {
		platforms = strings.Split(args[0], ",")
	}
	if len(platforms) == 0 {
		return fmt.Errorf("platform is required")
	}

	cubzhRepoRootDirPath := ""
	if len(args) > 1 {
		cubzhRepoRootDirPath = args[1]
	} else {
		// find git repo root directory
		var err error
		cubzhRepoRootDirPath, err = findPathToFirstParentGitRepo()
		if err != nil {
			return err
		}
	}
	if cubzhRepoRootDirPath == "" {
		return fmt.Errorf("cubzh repo root dir path is empty")
	}

	depsDirPath := filepath.Join(cubzhRepoRootDirPath, "deps")
	configJsonFilePath := filepath.Join(cubzhRepoRootDirPath, "bundle", "config.json")

	return deptool.Autoconfigure(objectStorageBuildFunc, depsDirPath, configJsonFilePath, platforms)
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

func objectStorageBuildFunc() (objectstorage.ObjectStorage, error) {
	// construct object storage client opts
	opts := deptool.DigitalOceanObjectStorageClientOpts{}
	authKey, authSecret, err := getObjectStorageCredentialsFromEnvVars()
	if err == nil {
		opts.AuthKey = authKey
		opts.AuthSecret = authSecret
	}
	objectStorage, err := deptool.NewDigitalOceanObjectStorageClient(opts)
	if err != nil {
		return nil, err
	}
	return objectStorage, nil
}
