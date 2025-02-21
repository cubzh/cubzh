package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
	"github.com/voxowl/objectstorage"
	"github.com/voxowl/objectstorage/digitalocean"
)

const (
	// Supported dependencies
	DependencyLibLuau = "libluau"
	// DependencyLibPNG  = "libpng"

	// Supported platforms
	PlatformAll     = "all"
	PlatformAndroid = "android"
	PlatformIOS     = "ios"
	PlatformMacos   = "macos"
	PlatformWindows = "windows"
	PlatformLinux   = "linux"
	// PlatformWeb     = "web"

	// Object storage credentials (env var names)
	digitalOceanSpacesAuthKeyEnvVar     = "CUBZH_DIGITALOCEAN_SPACES_AUTH_KEY"
	digitalOceanSpacesAuthSecretEnvVar  = "CUBZH_DIGITALOCEAN_SPACES_AUTH_SECRET"
	digitalOceanSpacesRegion            = "nyc3"
	digitalOceanSpacesBucket            = "cubzh-deps"
	digitalOceanSpacesAuthKeyDefault    = "DO8019TZD8N66GJGUEE3"
	digitalOceanSpacesAuthSecretDefault = "OVVGXIdaEXRG8TPi2/TmI3Ji/h56nZgetMxeYw9aXlk"
)

var (
	supportedDependencies = []string{DependencyLibLuau}
	supportedPlatforms    = []string{PlatformAndroid, PlatformIOS, PlatformMacos, PlatformWindows, PlatformLinux}
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

	// debug command
	// {
	// 	var debugCmd = &cobra.Command{
	// 		Use:   "debug",
	// 		Short: "Debug command",
	// 		RunE:  debugCmdFunc,
	// 	}
	// 	rootCmd.AddCommand(debugCmd)
	// }

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

// func debugCmdFunc(cmd *cobra.Command, args []string) error {
// 	dir, err := findPathToFirstParentGitRepo()
// 	if err != nil {
// 		return err
// 	}
// 	fmt.Println("🔍 found git repo at:", dir)
// 	return nil
// }

// deptool upload <dependency> <version> <platform>
//
// [dependency] supported values:
// - luau: luau prebuilt binaries
//
// [platform] supported values:
// - all: all supported platforms
// - android
// - ios
// - macos
// - windows
// - web (soon)
// - linux (soon)
//
// example: deptool upload libluau 0.661 macos
func uploadCmdFunc(cmd *cobra.Command, args []string) error {
	depName := args[0]
	version := args[1]
	platform := args[2]
	return uploadArtifacts(depName, version, platform)
}

// deptool download <dependency> <version> <platform>
//
// [dependency] supported values:
// - luau: luau prebuilt binaries
//
// [platform] supported values:
// - all: all supported platforms
// - android
// - ios
// - macos
// - windows
// - web (soon)
// - linux (soon)
//
// example: deptool download libluau 0.661 macos
func downloadCmdFunc(cmd *cobra.Command, args []string) error {
	depName := args[0]
	version := args[1]
	platform := args[2]
	forceFlag, err := cmd.Flags().GetBool("force")
	if err != nil {
		return err
	}
	return downloadArtifacts(depName, version, platform, forceFlag)
}

// -----------------------------
// Utility functions
// -----------------------------

func getObjectStorageClient() (objectstorage.ObjectStorage, error) {

	// Get credentials for object storage
	authKey := os.Getenv(digitalOceanSpacesAuthKeyEnvVar)
	authSecret := os.Getenv(digitalOceanSpacesAuthSecretEnvVar)
	// if only one of the two is set, return an error
	if (authKey == "" && authSecret != "") || (authKey != "" && authSecret == "") {
		return nil, fmt.Errorf("%s and %s must be both set (or not set at all)", digitalOceanSpacesAuthKeyEnvVar, digitalOceanSpacesAuthSecretEnvVar)
	}
	if authKey == "" && authSecret == "" {
		authKey = digitalOceanSpacesAuthKeyDefault
		authSecret = digitalOceanSpacesAuthSecretDefault
	}

	// Create the object storage client
	objectStorageClient, err := digitalocean.NewDigitalOceanObjectStorage(
		digitalocean.DigitalOceanConfig{
			Region:     digitalOceanSpacesRegion,
			Bucket:     digitalOceanSpacesBucket,
			AuthKey:    authKey,
			AuthSecret: authSecret,
		},
		digitalocean.DigitalOceanObjectStorageOpts{
			UsePathStyle: true,
		},
	)
	return objectStorageClient, err
}

func constructDepArtifactsPath(depName, version, platform string) string {
	return filepath.Join("deps", depName, version, "prebuilt", platform)
}

func constructDepArtifactsPathNew(depName, version, platform string) string {
	return filepath.Join(depName, version, "prebuilt", platform)
}

// func findPathToFirstParentGitRepo() (string, error) {
// 	limit := 100
// 	// Find the first parent directory that is a git repository
// 	dir, err := filepath.Abs(filepath.Dir(os.Args[0]))
// 	if err != nil {
// 		return "", err
// 	}
// 	// fmt.Println("🔍 searching for git repo in:", dir)
// 	for dir != "." {
// 		if _, err := os.Stat(filepath.Join(dir, ".git")); err == nil {
// 			return dir, nil
// 		}
// 		dir = filepath.Dir(dir)
// 		limit--
// 		if limit <= 0 {
// 			return "", fmt.Errorf("no git repository found")
// 		}
// 	}
// 	return "", fmt.Errorf("no git repository found")
// }
