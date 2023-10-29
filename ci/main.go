package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"strings"

	"dagger.io/dagger"
)

const (
	// Max number of files compiled by Ninja if there are compilation errors
	NB_MAX_BUILD_ERRORS string = "999"
)

var (
	githubOwner     string = ""
	githubRepo      string = ""
	githubCommitSha string = ""
	githubToken     string = ""
)

func main() {

	test := "linter"

	if len(os.Args) > 1 {
		test = os.Args[1] // linter, formater
	}

	repository := os.Getenv("GITHUB_REPOSITORY")
	if len(repository) > 0 {
		parts := strings.Split(repository, "/")
		if len(parts) == 2 {
			githubOwner = parts[0]
			githubRepo = parts[1]
		}
	}
	githubCommitSha = os.Getenv("GITHUB_SHA")
	githubToken = os.Getenv("GITHUB_TOKEN")

	err := testModules(test == "linter", test == "formater")
	if err != nil {
		fmt.Println(err)
		fmt.Println("FAILURE")
		os.Exit(1)
	}

	fmt.Println("SUCCESS")
	os.Exit(0)
}

func testModules(linter bool, formater bool) error {

	// postCheckRun("luacheck", "in_progress", "", nil)

	ctx := context.Background()

	// Initialize dagger client
	client, err := dagger.Connect(ctx,
		dagger.WithLogOutput(os.Stdout), // output the logs to the standard output
		dagger.WithWorkdir("../.."),     // go to cubzh root directory
	)
	if err != nil {
		// postCheckRun("luacheck", "completed", "failure", nil)
		return err
	}
	defer client.Close()

	ciContainer := client.Container().From("voxowl/luadev:1.0")

	// create a reference to host root dir
	dirOpts := dagger.HostDirectoryOpts{
		// include only the following directories
		Include: []string{"lua/modules"},
	}
	src := client.Host().Directory(".", dirOpts)

	// mount host directory to container and go into it
	ciContainer = ciContainer.WithMountedDirectory("/project", src)
	ciContainer = ciContainer.WithWorkdir("/project/lua/modules")

	if linter {
		ciContainer = ciContainer.WithExec([]string{"luacheck", "."})
	} else if formater {
		ciContainer = ciContainer.WithExec([]string{"stylua", "--check", "."})
	}

	ciContainer, err = ciContainer.Sync(ctx)
	if err != nil {
		var execErr *dagger.ExecError
		if errors.As(err, &execErr) {
			// err is an ExecError
			fmt.Println(execErr.Stderr)
			return errors.New("luacheck error")
		}
		fmt.Println("error syncing pipeline after exec")
		// postCheckRun("luacheck", "completed", "failure", nil)
		return err
	}

	// postCheckRun("luacheck", "completed", "success", nil)
	return nil
}

func postStatus(context string, state string) {
	opts := GithubStatusOpts{
		AccessToken: githubToken,
		Owner:       githubOwner,
		Repo:        githubRepo,
		Sha:         githubCommitSha,
		State:       state,
		Context:     context,
	}
	err := postGithubStatus(opts)
	if err != nil {
		fmt.Println("GIT STATUS ERR:", err.Error())
		fmt.Println("Owner:", opts.Owner, "Repo:", opts.Repo, "Sha:", opts.Sha)
	} else {
		fmt.Println("GIT STATUS OK", context, state)
	}
}

func postCheckRun(name string, status string, conclusion string, output *GithubCheckRunOutput) {
	checkRun := GithubCheckRun{
		Owner:      githubOwner,
		Repo:       githubRepo,
		Name:       name,
		Sha:        githubCommitSha,
		Status:     status,
		Conclusion: conclusion,
		Output:     output,
	}
	err := postGithubCheckRun(checkRun, githubToken)
	if err != nil {
		fmt.Println("GIT CHECK RUN ERR:", err.Error())
		fmt.Println("Owner:", checkRun.Owner, "Repo:", checkRun.Repo, "Sha:", checkRun.Sha, "Name:", checkRun.Name)
	} else {
		fmt.Println("GIT CHECK RUN OK", name, status, conclusion)
	}
}
