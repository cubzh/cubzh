package deptool

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/cubzh/cubzh/deps/deptool/utils"
)

const (
	// Name of the symlink to the active dependency version
	ACTIVE_DEPENDENCY_SYMLINK_NAME = "_active_"
)

func ActivateDependency(depsDirPath, depName, version string) error {
	var err error

	// path to dependency directory wanted to be activated
	depDirPath := filepath.Join(depsDirPath, depName)
	depVersionDirPath := filepath.Join(depDirPath, version)

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

	// if on windows, use mklink
	// if runtime.GOOS == "windows" {

	// remove existing "active" copy if it exists
	if _, err := os.Stat(symlinkPath); err == nil {
		err = os.RemoveAll(symlinkPath) // Use RemoveAll to handle non-empty directories
		if err != nil {
			return fmt.Errorf("failed to remove existing _active_: %w", err)
		}
	}

	// create a fresh "active" directory
	err = os.MkdirAll(symlinkPath, 0755)
	if err != nil {
		return fmt.Errorf("failed to create _active_ directory: %w", err)
	}

	// creating symlinks on windows requires admin privileges,
	// therefore we do a copy of the dependency version directory instead
	err = utils.CopyDirectory(depVersionDirPath, symlinkPath)
	if err != nil {
		return fmt.Errorf("failed to copy dependency version directory: %w", err)
	}

	// } else if runtime.GOOS == "darwin" || runtime.GOOS == "linux" {

	// 	// remove existing "active" copy if it exists
	// 	if _, err := os.Lstat(symlinkPath); err == nil {
	// 		err = os.Remove(symlinkPath)
	// 		if err != nil {
	// 			return fmt.Errorf("failed to remove existing _active_: %w", err)
	// 		}
	// 	}

	// 	// create a symlink to the requested version
	// 	err = os.Symlink(depVersionDirPath, symlinkPath)
	// 	if err != nil {
	// 		return fmt.Errorf("failed to create symlink: %w", err)
	// 	}

	// } else {
	// 	return fmt.Errorf("unsupported platform: %s", runtime.GOOS)
	// }

	return nil // success
}
