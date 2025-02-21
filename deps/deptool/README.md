# Cubzh Dependencies Tool (deptool)

## Setup access key

Add those lines to your `~/.bashrc` or `~/.zshrc` file:

```bash
# for read-only access
export CUBZH_DIGITALOCEAN_SPACES_AUTH_KEY="DO8019TZD8N66GJGUEE3"
export CUBZH_DIGITALOCEAN_SPACES_AUTH_SECRET="OVVGXIdaEXRG8TPi2/TmI3Ji/h56nZgetMxeYw9aXlk"
```

## Download dependencies

```bash
# move to the deptool directory
cd cubzh/deps/deptool

# download a dependency
# deptool download <dependency> <platform> [<version>]
deptool download libluau 0.661 android
deptool download libluau 0.661 ios
deptool download libluau 0.661 macos
deptool download libluau 0.661 windows
deptool download libluau 0.661 linux
```

## Upload dependencies

```bash
# move to the deptool directory
cd cubzh/deps/deptool

# upload a dependency
# deptool upload <dependency> <platform> [<version>]
deptool upload libluau 0.661 android
deptool upload libluau 0.661 ios
deptool upload libluau 0.661 macos
deptool upload libluau 0.661 windows
deptool upload libluau 0.661 linux
```

## Build deptool

### Build for current platforms

```bash
cd cubzh/deps/deptool
go build -o deptool_platforms
```

## Build in docker container

```bash
# execute from the "deps/deptool" directory
# Note: we force the platform to linux/amd64
docker run --platform linux/amd64 --rm -it -v $(pwd):/deptool -w /deptool golang:1.24.0-alpine3.21 go build -o deptool_linux_amd64
docker run --platform linux/arm64 --rm -it -v $(pwd):/deptool -w /deptool golang:1.24.0-alpine3.21 go build -o deptool_linux_arm64
```
