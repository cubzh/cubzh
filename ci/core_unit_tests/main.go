package main

import (
	"context"
	"errors"
	"fmt"
	"os"

	"dagger.io/dagger"
)

func main() {
	//fmt.Println("Hello Dagger!")

	err := buildAnRunCurrentDirectory()
	if err != nil {
		fmt.Println(err)
		fmt.Println("exit_failure")
		os.Exit(1)
	}
	fmt.Println("exit_success")
	os.Exit(0)

	//branch := "dagger"

	// err := buildAnRunBranch(branch)
	// if err != nil {
	// 	fmt.Println(err)
	// }

	//fmt.Println("The End. 🙂")

}

func buildAnRunCurrentDirectory() error {
	// Get background context
	ctx := context.Background()

	// Initialize dagger client
	client, err := dagger.Connect(ctx,
		dagger.WithLogOutput(os.Stdout), // output the logs to the standard output
		dagger.WithWorkdir("../.."),     // go to cubzh root directory
	)
	if err != nil {
		return err
	}
	defer client.Close()

	// create a reference to host root dir
	dirOpts := dagger.HostDirectoryOpts{
		// exclude the following directories
		Exclude: []string{"./ci", "./misc"},
	}
	src := client.Host().Directory(".", dirOpts)

	// build container with correct dockerfile
	buildOpts := dagger.ContainerBuildOpts{
		Dockerfile: "dockerfiles/ubuntu_build_env.Dockerfile",
	}
	ciContainer := client.Container().Build(src, buildOpts)

	// mount host directory to container and go into it
	ciContainer = ciContainer.WithMountedDirectory("/project", src)
	ciContainer = ciContainer.WithWorkdir("/project/core/tests/cmake")

	// execute build commands
	ciContainer = ciContainer.Exec(dagger.ContainerExecOpts{
		Args: []string{"cmake", "-G", "Ninja", "."},
	})
	output, err := ciContainer.Stdout().Contents(ctx)
	if err != nil {
		return err
	}
	fmt.Println(output)
	code, err := ciContainer.ExitCode(ctx)
	if err != nil {
		return err
	}
	if code != 0 {
		return errors.New("cmake error")
	}

	fmt.Println("Running tests in container...")
	ciContainer = ciContainer.Exec(dagger.ContainerExecOpts{
		Args: []string{"cmake", "--build", ".", "--clean-first"},
	})
	output, err = ciContainer.Stdout().Contents(ctx)
	if err != nil {
		return err
	}
	fmt.Println(output)
	code, err = ciContainer.ExitCode(ctx)
	if err != nil {
		return err
	}
	if code != 0 {
		return errors.New("cmake --build error")
	}

	ciContainer = ciContainer.Exec(dagger.ContainerExecOpts{
		Args: []string{"./unit_tests"},
	})
	output, err = ciContainer.Stdout().Contents(ctx)
	if err != nil {
		return err
	}
	fmt.Println(output)
	code, err = ciContainer.ExitCode(ctx)
	if err != nil {
		return err
	}
	if code != 0 {
		return errors.New("running error")
	}

	fmt.Println("Tests done!")
	return nil
}

// func buildAnRunBranch(branchName string) error {

// 	// Get background context
// 	ctx := context.Background()
// 	// Initialize dagger client
// 	client, err := dagger.Connect(ctx)
// 	if err != nil {
// 		return err
// 	}
// 	defer client.Close()

// 	fmt.Println("Cloning Git repository...")

// 	// Clone the cubzh repo at the specified branch
// 	repo := client.Git("github.com/cubzh/cubzh")
// 	repoID, err := repo.Branch(branchName).Tree().ID(ctx)
// 	if err != nil {
// 		return err
// 	}

// 	fmt.Println("Building Docker container...")
// 	// build container with correct dockerfile
// 	buildOpts := dagger.ContainerBuildOpts{
// 		Dockerfile: "./dockerfiles/ubuntu_build_env.Dockerfile",
// 	}
// 	ciContainer := client.Container().Build(repoID, buildOpts)

// 	fmt.Println("Running tests in container...")
// 	// set workdir and execute build commands
// 	ciContainer = ciContainer.WithWorkdir("/core/tests/cmake")
// 	ciContainer = ciContainer.Exec(dagger.ContainerExecOpts{
// 		Args: []string{"cmake", "-G", "Ninja", "."},
// 	})
// 	code, err := ciContainer.ExitCode(ctx)
// 	if err != nil {
// 		return err
// 	}
// 	if code != 0 {
// 		return errors.New("cmake error")
// 	}
// 	ciContainer = ciContainer.Exec(dagger.ContainerExecOpts{
// 		Args: []string{"cmake", "--build", "."},
// 	})
// 	code, err = ciContainer.ExitCode(ctx)
// 	if err != nil {
// 		return err
// 	}
// 	if code != 0 {
// 		return errors.New("cmake --build error")
// 	}
// 	ciContainer = ciContainer.Exec(dagger.ContainerExecOpts{
// 		Args: []string{"./unit_tests"},
// 	})
// 	code, err = ciContainer.ExitCode(ctx)
// 	if err != nil {
// 		return err
// 	}
// 	if code != 0 {
// 		return errors.New("running error")
// 	}
// 	output, err := ciContainer.Stdout().Contents(ctx)
// 	if err != nil {
// 		return err
// 	}
// 	fmt.Println(output)

// 	fmt.Println("Tests done!")

// 	return nil
// }
