package main

import (
	"errors"
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"github.com/voxowl/objectstorage"
	"github.com/voxowl/objectstorage/digitalocean"
)

const (
	DependencyAll  = "all"
	DependencyLuau = "luau"

	PlatformAll     = "all"
	PlatformAndroid = "android"
	PlatformIOS     = "ios"
	PlatformMacos   = "macos"
	PlatformWindows = "windows"
	// PlatformWeb     = "web"
	// PlatformLinux   = "linux"
)

var (
	supportedDependencies = []string{DependencyLuau}
	supportedPlatforms    = []string{PlatformAndroid, PlatformIOS, PlatformMacos, PlatformWindows}
)

var rootCmd = &cobra.Command{
	Use:   "deps",
	Short: "Dependencies management tool for Cubzh",
	Long:  `A CLI tool to manage dependencies for Cubzh, including uploading prebuilt artifacts to Object Storage.`,
}

// deptool upload
var uploadCmd = &cobra.Command{
	Use:   "upload <dependency> <platform> [<version>]",
	Short: "Upload prebuilt dependency artifacts to Object Storage",
	Long:  `Upload prebuilt dependency artifacts for a specific platform to Object Storage.`,
	Args:  cobra.RangeArgs(2, 3),
	RunE: func(cmd *cobra.Command, args []string) error {
		return uploadCmdFunc(args)
	},
}

// deptool download
var downloadCmd = &cobra.Command{
	Use:   "download [dependency] [platform]",
	Short: "Download prebuilt dependency artifacts from Object Storage",
	Long:  `Download prebuilt dependency artifacts for a specific platform from Object Storage.`,
	Args:  cobra.ExactArgs(2),
	RunE: func(cmd *cobra.Command, args []string) error {
		dependency := args[0]
		platform := args[1]
		fmt.Printf("🐞 Downloading artifacts for dependency: %s, platform: %s\n", dependency, platform)
		// TODO: Implement download logic here
		return nil
	},
}

func init() {
	rootCmd.AddCommand(uploadCmd)
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

// Command functions

// deptool upload <dependency> <platform> [<version>]
//
// [dependency] supported values:
// - all: all supported dependencies
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
// [version] optional, default is "latest"
//
// example: deptool upload luau macos
// example: deptool upload luau macos 0.693
func uploadCmdFunc(args []string) error {
	argDependency := args[0]
	argPlatform := args[1]
	argVersion := args[2]

	// If version is not provided, use "latest"
	if argVersion == "" {
		argVersion = "latest"
	}

	return UploadArtifacts(argDependency, argPlatform, argVersion)
}

// deptool download <dependency> <platform> [<version>]
//
// [dependency] supported values:
// - all: all supported dependencies
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
// example: deptool download luau macos
func downloadCmdFunc(args []string) error {
	// dependency := args[0]
	// platform := args[1]
	return errors.New("not implemented")
}

// Object storage client

func getObjectStorageClient() (objectstorage.ObjectStorage, error) {
	// Create the object storage client
	objectStorageClient, err := digitalocean.NewDigitalOceanObjectStorage(
		digitalocean.DigitalOceanConfig{
			Region:     "nyc3",
			Bucket:     "cubzh-deps",
			AuthKey:    os.Getenv("CUBZH_DIGITALOCEAN_SPACES_AUTH_KEY"),
			AuthSecret: os.Getenv("CUBZH_DIGITALOCEAN_SPACES_AUTH_SECRET"),
		},
		digitalocean.DigitalOceanObjectStorageOpts{
			UsePathStyle: true,
		},
	)
	return objectStorageClient, err
}
