package main

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"net"
	"net/url"
	"os"
	"os/exec"

	"dagger.io/dagger"
	"golang.org/x/crypto/ssh"
	"golang.org/x/crypto/ssh/knownhosts"
)

const (
	// path of repo root directory from local directory
	REPO_ROOT_PATH string = "../.."
	// path of Lua docs files from repo root directory
	LUA_DOCS_FILES_PATH       string = "./lua/docs"
	KNOWNHOSTS_LOCAL_FILEPATH string = "./known_hosts"
	// environment variables names
	DOCKER_REGISTRY_URL_ENVAR_NAME         string = "DOCKER_REGISTRY_URL"
	DOCKER_REGISTRY_TOKEN_ENVAR_NAME       string = "DOCKER_REGISTRY_TOKEN"
	LUA_DOCS_DOCKER_IMAGE_NAME_ENVAR_NAME  string = "LUA_DOCS_DOCKER_IMAGE_NAME"
	LUA_DOCS_SRV_SSH_URL_ENVAR_NAME        string = "LUA_DOCS_SRV_SSH_URL"
	LUA_DOCS_SRV_SSH_PRIVATEKEY_ENVAR_NAME string = "LUA_DOCS_SRV_SSH_PRIVATEKEY"
	LUA_DOCS_SRV_SSH_KNOWNHOSTS_ENVAR_NAME string = "LUA_DOCS_SRV_SSH_KNOWNHOSTS"
)

var (
	DOCKER_REGISTRY_URL            string = os.Getenv(DOCKER_REGISTRY_URL_ENVAR_NAME)
	DOCKER_REGISTRY_TOKEN          string = os.Getenv(DOCKER_REGISTRY_TOKEN_ENVAR_NAME)
	LUA_DOCS_DOCKER_IMAGE_NAME     string = os.Getenv(LUA_DOCS_DOCKER_IMAGE_NAME_ENVAR_NAME)
	LUA_DOCS_SRV_SSH_URL           string = os.Getenv(LUA_DOCS_SRV_SSH_URL_ENVAR_NAME)
	LUA_DOCS_SRV_SSH_PRIVATEKEY    string = os.Getenv(LUA_DOCS_SRV_SSH_PRIVATEKEY_ENVAR_NAME)
	LUA_DOCS_SRV_SSH_KNOWNHOSTS    string = os.Getenv(LUA_DOCS_SRV_SSH_KNOWNHOSTS_ENVAR_NAME)
	LUA_DOCS_DOCKER_IMAGE_FULLNAME string
	LUA_DOCS_SRV_SSH_USER          string
	LUA_DOCS_SRV_SSH_HOST          string
	LUA_DOCS_SRV_SSH_PORT          string
)

func main() {
	fmt.Println("⭐️ Deploying Cubzh Lua docs...")

	// Check all environment variables are present
	{
		missingEnvarName := ""
		if len(DOCKER_REGISTRY_URL) == 0 {
			missingEnvarName = DOCKER_REGISTRY_URL_ENVAR_NAME
		}
		if len(DOCKER_REGISTRY_TOKEN) == 0 {
			missingEnvarName = DOCKER_REGISTRY_TOKEN_ENVAR_NAME
		}
		if len(LUA_DOCS_DOCKER_IMAGE_NAME) == 0 {
			missingEnvarName = LUA_DOCS_DOCKER_IMAGE_NAME_ENVAR_NAME
		}
		if len(LUA_DOCS_SRV_SSH_URL) == 0 {
			missingEnvarName = LUA_DOCS_SRV_SSH_URL_ENVAR_NAME
		}
		if len(LUA_DOCS_SRV_SSH_PRIVATEKEY) == 0 {
			missingEnvarName = LUA_DOCS_SRV_SSH_PRIVATEKEY_ENVAR_NAME
		}
		if len(LUA_DOCS_SRV_SSH_KNOWNHOSTS) == 0 {
			missingEnvarName = LUA_DOCS_SRV_SSH_KNOWNHOSTS_ENVAR_NAME
		}
		if len(missingEnvarName) > 0 {
			fmt.Println("❌ Error: missing envar", missingEnvarName)
			os.Exit(1) // failure
		}
	}

	// Construct docker image fullname
	LUA_DOCS_DOCKER_IMAGE_FULLNAME = DOCKER_REGISTRY_URL + "/" + LUA_DOCS_DOCKER_IMAGE_NAME

	// Parse SSH connection URL
	{
		urlRes, err := url.Parse(LUA_DOCS_SRV_SSH_URL)
		if err != nil {
			fmt.Println("❌ Error:", err.Error())
			os.Exit(1) // failure
		}

		LUA_DOCS_SRV_SSH_USER = urlRes.User.String()
		LUA_DOCS_SRV_SSH_HOST = urlRes.Hostname()
		LUA_DOCS_SRV_SSH_PORT = urlRes.Port()

		if len(LUA_DOCS_SRV_SSH_USER) == 0 ||
			len(LUA_DOCS_SRV_SSH_HOST) == 0 ||
			len(LUA_DOCS_SRV_SSH_PORT) == 0 {
			fmt.Println("❌ Error: failed to parse LUA_DOCS_SRV_SSH_URL")
			os.Exit(1) // failure
		}
	}

	err := deployLuaDocs()
	if err != nil {
		fmt.Println("❌ Failed to deploy. Error:", err.Error())
		os.Exit(1) // failure
	}

	fmt.Println("✅ Success.")
	os.Exit(0) // success
}

func dockerRegistryLogin() error {
	cmd := exec.Command(
		"docker", "login", DOCKER_REGISTRY_URL,
		"--username", DOCKER_REGISTRY_TOKEN,
		"--password", DOCKER_REGISTRY_TOKEN)
	return cmd.Run()
}

func dockerRegistryLogout() error {
	cmd := exec.Command(
		"docker", "logout", DOCKER_REGISTRY_URL)
	return cmd.Run()
}

func deployLuaDocs() error {
	var err error

	// login to docker registry
	if err = dockerRegistryLogin(); err != nil {
		return err
	}
	defer dockerRegistryLogout()

	// Get background context
	ctx := context.Background()

	// Initialize dagger client
	client, err := dagger.Connect(ctx,
		dagger.WithLogOutput(os.Stdout),    // output the logs to the standard output
		dagger.WithWorkdir(REPO_ROOT_PATH), // repository root directory
	)
	if err != nil {
		return err
	}
	defer client.Close()

	// create a reference to host root dir
	// dirOpts := dagger.HostDirectoryOpts{
	// 	// exclude the following directories
	// 	Exclude: []string{".git", ".github"},
	// }
	src := client.Host().Directory(LUA_DOCS_FILES_PATH, dagger.HostDirectoryOpts{})

	// build container with correct dockerfile
	containerOpts := dagger.ContainerOpts{
		Platform: "linux/amd64",
	}
	buildOpts := dagger.ContainerBuildOpts{
		Dockerfile: "./Dockerfile",
	}
	docsContainer := client.Container(containerOpts).Build(src, buildOpts)
	if docsContainer == nil {
		fmt.Println("❌ docker image build failed")
		return errors.New("docker build failed")
	}

	//
	// TODO: inject commit hash into container & test the image,
	//       like we used to do with dagger CUE pipeline?
	//

	// Publish the image on our Docker registry
	// --------------------------------------------------
	{
		publishOpts := dagger.ContainerPublishOpts{}
		ref, err := docsContainer.Publish(ctx, LUA_DOCS_DOCKER_IMAGE_FULLNAME, publishOpts)
		if err != nil {
			fmt.Println("❌ docker image publish failed")
			return err
		}
		fmt.Println("✅ docker image publish OK (" + ref + ")")
	}

	// Update Swarm service with new image
	// --------------------------------------------------
	{
		// write known_hosts file
		err := os.WriteFile(KNOWNHOSTS_LOCAL_FILEPATH, []byte(LUA_DOCS_SRV_SSH_KNOWNHOSTS), 0600)
		if err != nil {
			return err
		}
		// will remove known_hosts file
		defer os.Remove(KNOWNHOSTS_LOCAL_FILEPATH)

		// execute remote command
		output, err := remoteRun(
			LUA_DOCS_SRV_SSH_USER,
			LUA_DOCS_SRV_SSH_HOST,
			LUA_DOCS_SRV_SSH_PORT,
			LUA_DOCS_SRV_SSH_PRIVATEKEY,
			KNOWNHOSTS_LOCAL_FILEPATH,
			"docker service update --with-registry-auth --image "+LUA_DOCS_DOCKER_IMAGE_FULLNAME+" lua-docs",
		)
		if err != nil {
			fmt.Println("❌ ssh call failed:", err.Error())
			return err
		}

		fmt.Println(output)
		fmt.Println("✅ docker service update OK")
	}

	fmt.Println("✅ Lua docs deployment done!")
	return nil
}

// e.g. output, err := remoteRun("root", <my_IP>, "22", <private_key>, <known_hosts>, "ls")
func remoteRun(user, addr, port, privateKey, knownhostsFilepath, cmd string) (string, error) {
	// privateKey could be read from a file, or retrieved from another storage
	// source, such as the Secret Service / GNOME Keyring
	key, err := ssh.ParsePrivateKey([]byte(privateKey))
	if err != nil {
		return "", err
	}

	hostKeyCallback, err := knownhosts.New(knownhostsFilepath)
	if err != nil {
		return "", err
	}

	// Authentication
	config := &ssh.ClientConfig{
		User:            user,
		HostKeyCallback: hostKeyCallback, // ssh.InsercureIgnoreHostKey to allow any host
		Auth: []ssh.AuthMethod{
			ssh.PublicKeys(key),
		},
	}

	// Connect
	client, err := ssh.Dial("tcp", net.JoinHostPort(addr, port), config)
	if err != nil {
		return "", err
	}
	// defer client.Close() // needed ?

	// Create a session. It is one session per command.
	session, err := client.NewSession()
	if err != nil {
		return "", err
	}
	defer session.Close()

	// Finally, run the command
	var b bytes.Buffer  // import "bytes"
	session.Stdout = &b // get output
	// you can also pass what gets input to the stdin, allowing you to pipe
	// content from client to server
	//      session.Stdin = bytes.NewBufferString("My input")
	err = session.Run(cmd)

	return b.String(), err
}
