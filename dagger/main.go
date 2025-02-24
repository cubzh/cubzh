// A generated module for Cubzh functions
//
// This module has been generated via dagger init and serves as a reference to
// basic module structure as you get started with Dagger.
//
// Two functions have been pre-created. You can modify, delete, or add to them,
// as needed. They demonstrate usage of arguments and return types using simple
// echo and grep commands. The functions can be called from the dagger CLI or
// from one of the SDKs.
//
// The first line in this comment block is a short description line and the
// rest is a long description with more detail on the module's purpose or usage,
// if appropriate. All modules should have a short description.

package main

import (
	"context"
	"dagger/cubzh/internal/dagger"
	"fmt"
	"strings"
)

const (
	// Max number of files compiled by Ninja if there are compilation errors
	NB_MAX_BUILD_ERRORS string = "999"
)

type Cubzh struct{}

// Run core unit tests
func (m *Cubzh) TestCore(
	ctx context.Context,
	// Source code
	// +defaultPath="/"
	// +ignore=["*", "!core", "!deps/libz"]
	src *dagger.Directory,
) error {
	// create container with source files
	ctr := dag.Container().From("voxowl/cpp-build-env:14.0.0")

	// retrieve container architecture and provide it as ENVAR inside the container
	{
		platform, err := ctr.Platform(ctx)
		if err != nil {
			return err
		}
		// platform is of the form "linux/arm64"
		// architecture is the second par of the platform string, after the '/'
		architecture := strings.Split(string(platform), "/")[1]
		ctr = ctr.WithEnvVariable("CUBZH_ARCH", architecture)
	}
	_, err := ctr.
		// mount host directory to container and go into it
		WithMountedDirectory("/project", src).
		WithWorkdir("/project/core/tests/cmake").
		// execute build commands
		WithExec([]string{"cmake", "-G", "Ninja", "."}).
		// Flags after `--` are transmitted as-is to the build system (Ninja, here)
		// Ninja will stop if this number of errors is reached : NB_MAX_BUILD_ERRORS
		WithExec([]string{"cmake", "--build", ".", "--clean-first", "--", "-k", NB_MAX_BUILD_ERRORS}).
		// exec compiled unit tests program
		WithExec([]string{"./unit_tests"}).
		Sync(ctx)
	return err
}

// Lint the core source code
func (m *Cubzh) LintCore(
	ctx context.Context,
	// Core source directory
	// +defaultPath="/"
	// +ignore=["*", "!core", "core/tests/visual_studio", "core/tests/xcode", "core/tests/cmake"]
	src *dagger.Directory,
) error {
	_, err := m.FormatCore(ctx, src, true)
	return err
}

// Format the core source code using clang tools
func (m *Cubzh) FormatCore(
	ctx context.Context,
	// Source code to format
	// +defaultPath="/"
	// +ignore=["*", "!core", "core/tests/visual_studio", "core/tests/xcode", "core/tests/cmake"]
	src *dagger.Directory,
	// Only check, don't fix
	// +optional
	check bool,
) (*dagger.Directory, error) {
	var script string
	if check {
		// set -e: exit on first error
		// set -o pipefail: keep the last non-0 exit code
		// -regex: all .h / .hpp / .c / .cpp files
		// -maxdepth 2: consider the files in /core and /core/tests
		// // --dry-run: do not apply changes
		script = `set -e ; set -o pipefail ; find ./core -maxdepth 2 -regex '^.*\\.\\(cpp\\|hpp\\|c\\|h\\)$' -print0 | xargs -0 clang-format --dry-run --Werror -style=file`
	} else {
		// -i: apply changes
		// --Werror: consider warnings as errors
		// -style-file: follow the rules from the .clang-format file
		script = `echo 'set -e ; set -o pipefail ; find ./core -maxdepth 2 -regex '^.*\\.\\(cpp\\|hpp\\|c\\|h\\)$' -print0 | xargs -0 clang-format -i --Werror -style=file' > script.sh; exit 1`
	}
	output := dag.
		Container().
		From("gaetan/clang-tools").
		WithMountedDirectory("/project", src).
		WithWorkdir("/project").
		WithExec([]string{"ash", "-c", script}).
		Directory(".")
	if check {
		return output.Sync(ctx)
	}
	return output, nil
}

// Build a Lua dev container with modules source code mounted
func (m *Cubzh) LuaDev(
	// Lua modules source code
	// +defaultPath="/"
	// +ignore=["*", "!lua/modules"]
	src *dagger.Directory,
) *dagger.Container {
	return dag.
		Container().
		From("voxowl/luadev:1.0").
		WithMountedDirectory("/project", src).
		WithWorkdir("/project")
}

func (m *Cubzh) LintModules(
	ctx context.Context,
	// Modules source directory
	// +defaultPath="/"
	// +ignore=["*", "!lua/modules"]
	src *dagger.Directory,
) error {
	// _, err := m.
	// 	LuaDev(src).
	// 	WithExec([]string{"luacheck", "."}).
	// 	WithExec([]string{"stylua", "--check", "."}).
	// 	Sync(ctx)
	// return err
	fmt.Println("[🐞] NOT IMPLEMENTED YET")
	return nil
}
