# Contributing to Cubzh

Cubzh uses [Dagger](https://dagger.io) for its build, test and deployment pipelines.
You can run these pipelines locally while developing, and we also run them in our CI.

## Initial setup

You will need to install the [Dagger CLI](https://docs.dagger.io/install).
You will also need [Docker](https://docker.com) or a compatible tool.

## Dagger tips

- Dagger pipelines can be composed dynamically out of individual functions. You can discover available functions with `dagger functions`.
- Functions can be chained. For example try `dagger call lua-dev with-mounted-directory --source=https://github.com/cubzh/cubzh --path=/src/cubzh with-workdir --path=/src terminal`
- If something fails in the dagger pipeline, try `dagger call --interactive`. This will open an interactive shell in the container state where the error occured.

## Testing

Run the core test suite from a local checkout:

```bash
dagger call test-core --src=.:test-core
```

Run the core test suite directly from a pull request (this doesn't require a local checkout):

```bash
PR=506 # change to the PR number of your choice
dagger call -m github.com/cubzh/cubzh@pull/$PR/merge test-core --src https://github.com/cubzh/cubzh#pull/$PR/merge
```

## Linting and formatting

Checks the format of the code for Core and its tests following the format rules in `core/.clangformat`.

```bash
dagger call lint-core --src=.:lint-core
```

Modify the code so it complies with the format rules:

```bash
dagger call format-core --src=.:lint-core -o .
```

## Lua dev environment

```bash
dagger call lua-dev --src=.:modules terminal
```
Opens an interactive terminal in an ephemeral container, with the lua dev tools installed and source code mounted
