References:
https://emscripten.org/docs/getting_started/downloads.html
https://developer.mozilla.org/en-US/docs/WebAssembly/C_to_wasm
https://emscripten.org/docs/porting/connecting_cpp_and_javascript/Interacting-with-code.html
	-> method chosen for wrapper: https://emscripten.org/docs/porting/connecting_cpp_and_javascript/Interacting-with-code.html#call-compiled-c-c-code-directly-from-javascript
https://emscripten.org/docs/compiling/Building-Projects.html

# Environment setup

## Platform-specific requirements

### Windows

Install latest stable Python release for Windows if you don't have any. Choose to add to PATH during install. The version doesn't matter since Emscripten SDK will install an appropriate Python version, but you need to have the Python launcher available.
	Source: https://www.python.org/downloads/windows/

If on Windows 10, you may have a permission error linked to Python when trying to use it. To fix this, you need to disable the Python installer from the Windows Store by typing "manage app execution aliases" and disable all entries for Python.

For CLI on Windows, use Git Bash.

Make sure to have `cmake` available somewhere in your PATH.
	Source: https://cmake.org/download/

### Mac

There is normally nothing specific to do. You can check requirements here:  https://emscripten.org/docs/getting_started/downloads.html#platform-notes-installation-instructions-sdk

## Emscripten SDK

The SDK archive is on the particubes-private repo in /wasm, you don't need to download it.
	Currently using: 3.1.38
	Source: https://github.com/emscripten-core/emsdk/tree/3.1.38

Unzip to /wasm/emsdk and move to the folder then,
1) install SDK `./emsdk install [version]`, this downloads dependencies for this SDK version in the folder.
2) activate the SDK `./emsdk activate [version]`, this makes that version of Emscripten the default version used on your machine.
3) [not necessary on Windows] setup env variables `source ./emsdk_env.sh`

From there on, we can use the Emscripten compiler `emcc`. On Windows, use `emcmdprompt.bat` located in the SDK folder to access `emcc`.

You can use `emsdk list` to see available packages and `install` then `activate` any you need. For example on windows, we can add `mingw`,
```
emsdk install mingw-7.1.0-64bit
emsdk activate mingw-7.1.0-64bit
```

Check that your setup is correct by running,
- `emcc --check` : you should see no warning
- `emcc` : you should see "error: no input files"

Useful commands,
- `emcmake cmake --help` : you should see list of available generators
- `emcc --show-ports` : list of available ports for compiling with `emcc`

# Compiling project

You can use `build.sh`, which is equivalent to doing,
```
emcmake cmake -B ./build
cd ./build
emcmake cmake .
emmake make -j8
```
Libs & makefiles will be in `build/` and wasm output in `build/output`.

You can make a clean build by calling `emmake make clean` before `make` or emptying the whole content of `build/`.

# Testing

For testing, we need a local HTTP server.

In Chrome, you can use ctrl+shift+I to open dev tools & see error outputs in JS console

## Go server (recommended)

A local HTTP server is available on the repo,
- start it using `run_server.sh`
- access `http://localhost:8080/<output>.html` in browser

## Simple Python server

Go where the wasm output is located then,
- use `python -m http.server`
- access `http://localhost:8000/<output>.html` in browser

This won't work to run the game as it lacks headers allowing the use of pthreads, however it can be used to test the HTML shell and the JS module
