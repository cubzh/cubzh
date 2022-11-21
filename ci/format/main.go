package main

import (
	"context"
	"errors"
	"fmt"
	"os"

	"dagger.io/dagger"
)

func main() {
	doFormat := false
	if len(os.Args) >= 2 && os.Args[1] == "--apply-changes" {
		doFormat = true
	}

	err := checkFormat(doFormat)
	if err != nil {
		fmt.Println(err)
		fmt.Println("exit_failure")
		os.Exit(1)
	}

	fmt.Println("exit_success")
	os.Exit(0)
}

func checkFormat(doFormat bool) error {
	// Get background context
	ctx := context.Background()

	// Initialize dagger client with options
	client, err := dagger.Connect(ctx,
		dagger.WithLogOutput(os.Stdout), // output the logs to the standard output
		dagger.WithWorkdir("../.."),     // go to cubzh root directory
	)
	if err != nil {
		return err
	}
	defer client.Close()

	// create a reference to host root dir
	dirOpts := dagger.HostWorkdirOpts{
		// exclude the following directories
		Exclude: []string{".git", "ci", "dockerfiles", "misc"},
	}
	src := client.Host().Workdir(dirOpts)

	// get Docker container from hub
	ciContainer := client.Container().From("gaetan/clang-tools")

	// mount host directory to container and go into it
	ciContainer = ciContainer.WithMountedDirectory("/project", src)
	ciContainer = ciContainer.WithWorkdir("/project")

	command := ""
	if doFormat {
		// set -e: exit on first error
		// set -o pipefail: keep the last non-0 exit code
		// -regex: all .h / .hpp / .c / .cpp files
		// -maxdepth 2: consider the files in /core and /core/tests
		// -i: apply changes
		// --Werror: consider warnings as errors
		// -style-file: follow the rules from the .clang-format file
		command = "set -e ; set -o pipefail ; find ./core -maxdepth 2 -regex '^.*\\.\\(cpp\\|hpp\\|c\\|h\\)$' -print0 | xargs -0 clang-format -i --Werror -style=file"
	} else {
		// --dry-run: do not apply changes
		command = "set -e ; set -o pipefail ; find ./core -maxdepth 2 -regex '^.*\\.\\(cpp\\|hpp\\|c\\|h\\)$' -print0 | xargs -0 clang-format --dry-run --Werror -style=file"
	}

	// run the clang command on every file
	ciContainer = ciContainer.Exec(dagger.ContainerExecOpts{
		// ash -c is necessary because piping is used
		Args: []string{"ash", "-c", command},
	})

	// get the exit code
	code, err := ciContainer.ExitCode(ctx)
	if err != nil {
		fmt.Println("error getting the exitcode")
		return err
	}
	if code != 0 && doFormat == false {
		return errors.New("incorrect format")
	}

	if doFormat {
		output := ciContainer.Directory(".")
		_, err = output.Export(ctx, ".")
		if err != nil {
			return err
		}

		fmt.Println("Formating done!")
	} else {
		fmt.Println("No format errors!")
	}

	return nil
}
