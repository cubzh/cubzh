# Cubzh Dependencies Tool (deptool)

## Basic usage

### Download a dependency

```sh
# deptool download <dependency> <version> <platform>
deptool download libluau 0.661 macos
deptool download libluau 0.661 ios
deptool download libluau 0.661 android
deptool download libluau 0.661 windows
deptool download libluau 0.661 linux
```

### Make downloaded dependency version active

```sh
# deptool activate <dependency> <version>
deptool activate libluau 0.661
deptool activate libluau 0.661
deptool activate libluau 0.661
deptool activate libluau 0.661
deptool activate libluau 0.661
```

## Advanced usage

### Setup access key (optional)

Add those lines to your `~/.bashrc` or `~/.zshrc` file:

```bash
# for read-only access
export CUBZH_DIGITALOCEAN_SPACES_AUTH_KEY="DO8019TZD8N66GJGUEE3"
export CUBZH_DIGITALOCEAN_SPACES_AUTH_SECRET="OVVGXIdaEXRG8TPi2/TmI3Ji/h56nZgetMxeYw9aXlk"
```

## Upload dependencies

```bash
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
# /!\ execute from the "deps/deptool/cmd" directory

# macos (arm64)
go build -o deptool_macos_arm64

# windows (x86_64)
go build -o deptool_windows_amd64
```

## Build in docker container

```bash
# /!\ execute from the "deps/deptool/cmd" directory

docker run --platform linux/amd64 --rm -it -v $(pwd)/..:/deptool -w /deptool/cmd golang:1.24.1-alpine3.21 go build -o deptool_linux_amd64
docker run --platform linux/arm64 --rm -it -v $(pwd)/..:/deptool -w /deptool/cmd golang:1.24.1-alpine3.21 go build -o deptool_linux_arm64
```
