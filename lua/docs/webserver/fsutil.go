package main

import (
	"os"
)

// Any file exists (regular or directory or other)
func fileExists(absPath string) bool {
	_, err := os.Stat(absPath)
	return err == nil
}

// Regular file exists
func regularFileExists(absPath string) bool {
	fd, err := os.Open(absPath)
	if err != nil {
		return false
	}
	fi, err := fd.Stat()
	if err != nil {
		return false
	}
	return fi.IsDir() == false
}

// Directory exists
func directoryExists(absPath string) bool {
	s, err := os.Stat(absPath)
	if err != nil {
		return false
	}
	return s.IsDir()
}
