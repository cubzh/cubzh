package main

import (
	"context"
	"errors"
	"fmt"
	"os"

	"dagger.io/dagger"
)

func main() {
	err := checkFormat()
	if err != nil {
		fmt.Println(err)
		fmt.Println("exit_failure")
		os.Exit(1)
	}

	fmt.Println("exit_success")
	os.Exit(0)
}

func checkFormat() error {
	repoRootDir := "../.." // git repository root directory
	repoRootID := "rootPath"

	// Get background context
	ctx := context.Background()

	// Initialize dagger client with options
	client, err := dagger.Connect(ctx,
		dagger.WithLogOutput(os.Stdout),              // output the logs to the standard output
		dagger.WithLocalDir(repoRootID, repoRootDir), // map the root dir to the engine
	)
	if err != nil {
		return err
	}
	defer client.Close()

	// configure local directory
	rootHostDir := client.Host().Directory(dagger.HostDirectoryID(repoRootID))
	rootDir := rootHostDir.Read()

	// get Docker container from hub
	ciContainer := client.Container().From("gaetan/clang-tools")

	// create a Directory and copy files into it
	rootDirID, err := rootDir.ID(ctx)
	if err != nil {
		// TODO: handle error
		return err
	}
	ciContainer = ciContainer.WithMountedDirectory("/project", rootDirID)
	ciContainer = ciContainer.WithWorkdir("/project") // go to the directory

	// run the clang command on every file
	ciContainer = ciContainer.Exec(dagger.ContainerExecOpts{
		// ash -c is necessary because piping is used
		// set -e: exit on first error
		// set -o pipefail: keep the last non-0 exit code
		// -regex: all .h / .hpp / .c / .cpp files
		// -maxdepth 2: consider the files in /core and /core/tests
		// --dry-run: do not apply changes
		// --Werror: consider warnings as errors
		// -style-file: follow the rules from the .clang-format file
		Args: []string{"ash", "-c", "set -e ; set -o pipefail ; find ./core -maxdepth 2 -regex '^.*\\.\\(cpp\\|hpp\\|c\\|h\\)$' -print0 | xargs -0 clang-format --dry-run --Werror -style=file"},
	})

	// get the exit code
	code, err := ciContainer.ExitCode(ctx)
	if err != nil {
		fmt.Println("error getting the exitcode")
		return err
	}
	if code == 0 {
		fmt.Println("No format errors!")
		return nil
	}

	// there was an error, log it
	output, err := ciContainer.Stdout().Contents(ctx)
	if err != nil {
		fmt.Println("error getting the contents")
		return err
	}
	fmt.Println(output)

	return errors.New("incorrect format")
}
