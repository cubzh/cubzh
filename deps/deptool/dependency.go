package deptool

import (
	"path/filepath"
	"slices"
)

const ( // Supported dependencies
	DependencyLibLuau = "libluau"
	// DependencyLibPNG  = "libpng"

	// Supported platforms
	PlatformAll     = "all"
	PlatformSource  = "source"
	PlatformAndroid = "android"
	PlatformIOS     = "ios"
	PlatformMacos   = "macos"
	PlatformWindows = "windows"
	PlatformLinux   = "linux"

	// PlatformWeb     = "web"
)

var (
	supportedDependencies = []string{DependencyLibLuau}
	supportedPlatforms    = []string{PlatformSource, PlatformAndroid, PlatformIOS, PlatformMacos, PlatformWindows, PlatformLinux}
)

func isDependencyNameValid(name string) bool {
	return slices.Contains(supportedDependencies, name)
}

func isPlatformNameValid(name string) bool {
	return slices.Contains(supportedPlatforms, name) || name == PlatformAll
}

func constructDepArtifactsPath(depName, version, platform string) string {
	return filepath.Join(depName, version, "prebuilt", platform)
}
