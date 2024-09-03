set -e

# create build directory if it doesn't exist
mkdir -p ./build

# --------------------------------------------------
# copy asset bundle in the wasm build directory
# --------------------------------------------------
rm -Rf ./build/bundle
# bundle files
cp -R ../../common/assets ./build/bundle
cp -R ../../cubzh/i18n ./build/bundle
# open-source Lua modules
cp -R ../../cubzh/lua/modules ./build/bundle
# remove unused shaders
rm -rf ./build/bundle/shaders/dx9
rm -rf ./build/bundle/shaders/dx11
rm -rf ./build/bundle/shaders/glsl
rm -rf ./build/bundle/shaders/metal
rm -rf ./build/bundle/shaders/spirv

# remove output (products)
rm -Rf ./build/output/*

emcmake cmake -B ./build
emcmake cmake ./build
#emmake make clean
emmake cmake --build ./build --parallel 4

# copy static files in the wasm output directory
cp -R static ./build/output

# Add .gz extention to cubzh.wasm & cubzh.data in cubzh.js

sed 's/cubzh.wasm/cubzh.wasm.gz/g' ./build/output/cubzh.js > ./build/output/cubzh-2.js
rm ./build/output/cubzh.js
mv ./build/output/cubzh-2.js ./build/output/cubzh.js

sed 's/cubzh.data/cubzh.data.gz/g' ./build/output/cubzh.js > ./build/output/cubzh-2.js
rm ./build/output/cubzh.js
mv ./build/output/cubzh-2.js ./build/output/cubzh.js
