
cmake_minimum_required(VERSION 3.20)
project(Cubzh)

set(CMAKE_CXX_STANDARD 14)

# Build options
set(HEADLESS FALSE)
set(DEBUG FALSE)
set(BGFX_DEBUG FALSE)

set(REPO_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../..")

set(COMMON_DIR "${REPO_ROOT_DIR}/common")
set(SBS_DIR "${COMMON_DIR}/VXLuaSandbox")
set(CUTILS_DIR "${COMMON_DIR}/CUtils")
set(LUA_DIR "${COMMON_DIR}/Lua/src")
set(LUAUTILS_DIR "${COMMON_DIR}/LuaUtils")
set(KIWI_DIR "${COMMON_DIR}/kiwi")
set(VX_DIR "${COMMON_DIR}/VXFramework")
set(VX_SERVER_DIR "${COMMON_DIR}/VXGameServer")
set(VXNETWORKING_DIR "${COMMON_DIR}/VXNetworking")
set(BX_DIR "${COMMON_DIR}/bgfx/bx")
set(BGFX_DIR "${COMMON_DIR}/bgfx/bgfx")
set(BIMG_DIR "${COMMON_DIR}/bgfx/bimg")
set(BGFX_COMMON_DIR "${COMMON_DIR}/bgfx/bgfx/examples/common")
set(DEPS_MINIAUDIO_DIR "${REPO_ROOT_DIR}/cubzh/deps/miniaudio")
# Cubzh Core
set(CUBZH_CORE_DIR "${REPO_ROOT_DIR}/cubzh/core")

# Emscripten compiler flags,
# -s USE_ZLIB=1
#       include emscripten port for ZLIB
# -s USE_PTHREADS=1
#       enable support for POSIX threads used by std::thread, note: not supported by all browsers (check https://webassembly.org/roadmap/)
set(EMCC_COMPILER_FLAGS  "-s USE_ZLIB=1\
                          -s USE_PTHREADS=1\
                          -Wbad-function-cast\
                          -Wcast-function-type\
                          ")
if (DEBUG)
        set(EMCC_COMPILER_FLAGS  "${EMCC_COMPILER_FLAGS}\
                                  -g\
                                  -gsource-map\
                                  ")
        set(CMAKE_BUILD_TYPE "Debug")
        # disable tracking in DEBUG builds
        # add_compile_options(-DP3S_NO_METRICS)
else()
        set(CMAKE_BUILD_TYPE "Release")
endif()

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${EMCC_COMPILER_FLAGS}")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${EMCC_COMPILER_FLAGS}")

# Emscripten linker options common to all builds,
# -bind
#       allow C/C++ to JS bindings (see vx-wrapper.cpp)
# -s WASM=1
#       get wab assembly output (wasm) instead of javascript for older browsers
# -s NO_EXIT_RUNTIME=1
#       prevent runtime from stoping when main() exits
# -s EXPORTED_RUNTIME_METHODS=[...]
#       list of runtime functions that we want available from JS (eg. ccall to call C function from JS)
# -s EXPORTED_FUNCTIONS=[...]
#       list of compiled functions that we want available from JS (_main is necessary at minimum)
# --shell-file
#       run the build through given HTML template
# --pre-js
# --post-js
#       inject JS file before/after the emitted code
# -- USE_PTHREADS
# -- PTHREAD_POOL_SIZE
# -- PTHREAD_POOL_SIZE_STRICT
#       enable support for POSIX threads, set predefined worker pool size
# -s MIN_WEBGL_VERSION=2
# -s MAX_WEBGL_VERSION=2
#       enable the creation of WebGL2 context (max), drop support for WebGL1 (min)
# -s FULL_ES2=1
# -s FULL_ES3=1
#       enable emulation of full ES2 / ES3 features
# -s ALLOW_MEMORY_GROWTH=1
#       we also could use -s INITIAL_MEMORY=X w/ a fixed amount
# -s ASYNCIFY=1
# -s ASYNCIFY_IMPORTS=[...]
#       enable the use of async JS from synchronous C/C++ on specified functions, by using Asyncify.handleAsync()
#       this also lets the Asyncify instrumentation know that nothing else needs to have the required overhead for asyncify
# -s FETCH=1
#       allow using the Fetch API (XMLHttpRequest : GET, PUT, POST)
#
# For DEBUG build we additionally use,
# -s LLD_REPORT_UNDEFINED
#       get readable info on undefined symbols
# -s DEMANGLE_SUPPORT=1
#       get readable function names in stack traces
# -s ASSERTIONS=1
#       enable runtime checks, set to 2 to run additional tests
# -s SAFE_HEAP=1
#       enable memory access checks
# -s EXCEPTION_DEBUG=1
#       this apparently makes our Module.printErr be called on an exception (not used currently)
# -fexceptions
#       enable exception catching JS-side
#       note: -fwasm-exceptions is also available for native wasm exception handling, but supported only in Chrome currently (check https://webassembly.org/roadmap/)
#
# For RELEASE build,
# -O3
#       optimization level, code is minified at O2 and above
set (EMCC_LINKER_FLAGS "--bind\
                        -s WASM=1\
                        -s NO_EXIT_RUNTIME=1\
                        -s \"EXPORTED_RUNTIME_METHODS=['ccall']\"\
                        -s \"EXPORTED_FUNCTIONS=['_main', '_malloc']\"\
                        --pre-js ${CMAKE_CURRENT_SOURCE_DIR}/vx-wrapper-pre-js.js\
                        --post-js ${CMAKE_CURRENT_SOURCE_DIR}/vx-wrapper-post-js.js\
                        -s USE_PTHREADS=1\
                        -s PTHREAD_POOL_SIZE=32\
                        -s PTHREAD_POOL_SIZE_STRICT=2\
                        --preload-file bundle\
                        -lidbfs.js\
                        -lwebsocket.js\
                        -s MIN_WEBGL_VERSION=2\
                        -s MAX_WEBGL_VERSION=2\
                        -s FULL_ES2=1\
                        -s FULL_ES3=1\
                        -s ALLOW_MEMORY_GROWTH=1\
                        -s ASYNCIFY=1\
                        -s \"ASYNCIFY_IMPORTS=['copy', 'paste']\"\
                        -s FETCH=1\
                        ")
                        # -s ERROR_ON_WASM_CHANGES_AFTER_LINK\
                        # -s PTHREAD_POOL_DELAY_LOAD=1
                        
if (DEBUG)
        set(EMCC_LINKER_FLAGS  "${EMCC_LINKER_FLAGS}\
                                --shell-file ${CMAKE_CURRENT_SOURCE_DIR}/shell_production.html\
                                -s LLD_REPORT_UNDEFINED\
                                -s DEMANGLE_SUPPORT=1\
                                -s ASSERTIONS=1\
                                -s SAFE_HEAP=2\
                                -s EXCEPTION_DEBUG=1\
                                -fexceptions\
                                --source-map-base ./\
                                -O0\
                                ")
                                
else()
        set(EMCC_LINKER_FLAGS  "${EMCC_LINKER_FLAGS}\
                                --shell-file ${CMAKE_CURRENT_SOURCE_DIR}/shell_production.html\
                                -O3\
                                ")
endif()

# Output type, maps to emscripten -o <target>
set(CMAKE_EXECUTABLE_SUFFIX ".html")
set(EXECUTABLE_OUTPUT_PATH "output")

# Compile options
add_compile_options(
        
        # define custom macros
        -D__VX_PLATFORM_WASM
        -DCLIENT_ENV # client env runs game tick
                
        # bgfx compilation
        #-DBGFX_CONFIG_RENDERER_OPENGLES=31
        -DBGFX_CONFIG_RENDERER_OPENGLES=30
        -DBGFX_CONFIG_RENDERER_USE_EXTENSIONS=1
        -DBGFX_CONFIG_MULTITHREADED=0
        -DBGFX_GL_CONFIG_TEXTURE_READ_BACK_EMULATION=1
        -DBGFX_GL_CONFIG_BLIT_EMULATION=1

        # ImGui compilation
        -DIMGUI_USE_WCHAR32

        -DPARTICUBES_VERSION="0.0.68"
        -DCUBZH_BUILD="171"
)

if(HEADLESS)
    message(STATUS "/!\ Building in headless mode")
    add_compile_options(
            -DP3S_CLIENT_HEADLESS
    )
endif()

if (BGFX_DEBUG)
    add_compile_options(
            -DBGFX_CONFIG_DEBUG
    )
endif()

### Libraries

# xptools
include(xptools.cmake)

# lua
file(GLOB LUA_SOURCES
        ${LUA_DIR}/*.c ${LUA_DIR}/*.h)
add_library(lua STATIC
        ${LUA_SOURCES})
target_compile_options(
        lua PRIVATE
        # This will rename any main() function to prevent EXPORTED_FUNCTIONS from capturing them
        "SHELL:-D main=__main"
)

# sbs
file(GLOB_RECURSE SBS_SOURCES
        CONFIGURE_DEPENDS
        ${SBS_DIR}/*.c ${SBS_DIR}/*.h ${SBS_DIR}/*.cpp ${SBS_DIR}/*.hpp)
add_library(sbs STATIC
        ${SBS_SOURCES})

# engine, no recurse to exclude tests/
file(GLOB ENGINE_SOURCES
        CONFIGURE_DEPENDS
        LIST_DIRECTORIES false
        ${CUBZH_CORE_DIR}/*.c ${CUBZH_CORE_DIR}/*.h
        ${CUTILS_DIR}/*.c ${CUTILS_DIR}/*.cpp ${CUTILS_DIR}/*.h
        ${LUAUTILS_DIR}/*.c ${LUAUTILS_DIR}/*.h)
add_library(engine STATIC
        ${ENGINE_SOURCES})

# vx framework
file(GLOB_RECURSE VX_SOURCES
        CONFIGURE_DEPENDS
        ${VX_DIR}/*.c ${VX_DIR}/*.cpp ${VX_DIR}/*.h ${VX_DIR}/*.sc ${VX_DIR}/*.hpp
        ${VX_SERVER_DIR}/*.hpp ${VX_SERVER_DIR}/*.cpp
        ${VXNETWORKING_DIR}/*.hpp ${VXNETWORKING_DIR}/*.cpp)
        
list(REMOVE_ITEM VX_SOURCES "${VX_SERVER_DIR}/main.cpp")
add_library(vx STATIC
        ${VX_SOURCES})

# vx framework - extract unique paths for includes
set(VX_DIRS "")
foreach(VX_FILE IN ITEMS ${VX_SOURCES})
    get_filename_component(VX_PATH ${VX_FILE} PATH)
    list(APPEND VX_DIRS ${VX_PATH})
endforeach()
list(REMOVE_DUPLICATES VX_DIRS)

if(NOT HEADLESS)
        # bgfx, bx, bimg, dear-imgui
        include(bgfx.cmake)
        include(cmake/3rdparty/dear-imgui.cmake)

        # bgfx rendering backend for dear-imgui
        set(BGFX_IMGUI_SOURCES "")
        foreach(DIR "${BGFX_COMMON_DIR}/imgui")
        file(GLOB GLOB_SOURCES ${DIR}/*.c ${DIR}/*.cpp ${DIR}/*.h ${DIR}/*.sc)
        list(APPEND BGFX_IMGUI_SOURCES ${GLOB_SOURCES})
        endforeach()
        add_library(bgfx-imgui STATIC
                ${BGFX_IMGUI_SOURCES})
endif()

# lpng
include(lpng.cmake)

### Includes

include_directories(
        ${CUBZH_CORE_DIR}
        ${LUA_DIR}
        ${SBS_DIR}
        ${KIWI_DIR}
        ${VX_DIRS}
        ${BGFX_DIR}/3rdparty
        ${BGFX_DIR}/3rdparty/dear-imgui
        ${BGFX_COMMON_DIR}
        ${VXTOOLS_INCLUDE_DIR}
        ${VXTOOLS_DEPS_DIR}
        ${LPNG_DIR}
        ${DEPS_MINIAUDIO_DIR})

# Debug: display include directories
#[[get_property(dirs DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY INCLUDE_DIRECTORIES)
# foreach(dir ${dirs})
#     message(STATUS "dir='${dir}'")
# endforeach()]]

### Linking

target_link_libraries(engine
        lua)

target_link_libraries(sbs
        lua vx)

if(NOT HEADLESS)
    target_link_libraries(bgfx-imgui
            bx bimg bgfx dear-imgui)

    target_link_libraries(vx
            bgfx-imgui)
endif()

target_link_libraries(vx
        engine 
        sbs
        xptools
        lpng
)

### Executable

add_executable(cubzh vx-wrapper.cpp)
target_link_libraries(cubzh vx)
set_target_properties(cubzh PROPERTIES LINK_FLAGS "${EMCC_LINKER_FLAGS}")
