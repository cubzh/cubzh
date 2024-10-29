#!/bin/sh

# INPUT_DIR="/www"
INPUT_DIR="../content"
REFERENCE_DIR="$INPUT_DIR/reference"
OUTPUT_FILE="./data.jsonl"

rm -f "$OUTPUT_FILE"


export LUA_PATH="$HOME/.luarocks/share/lua/5.3/?.lua;$HOME/.luarocks/share/lua/5.3/?/init.lua;;"
export LUA_CPATH="$HOME/.luarocks/lib/lua/5.3/?.so;;"

# ONE FILE ONLY, FOR DEBUG

file="$REFERENCE_DIR/http.yml"
name="$(basename -- $file)"
extension="${name##*.}"
filename="${name%.*}"
lua5.3 fine-tuning-data-exporter.lua "$file" "$OUTPUT_FILE"
echo "$file -> $OUTPUT_FILE"

file="$REFERENCE_DIR/json.yml"
name="$(basename -- $file)"
extension="${name##*.}"
filename="${name%.*}"
lua5.3 fine-tuning-data-exporter.lua "$file" "$OUTPUT_FILE"
echo "$file -> $OUTPUT_FILE"



# for file in "$INPUT_DIR"/*.lua
# do
#   name="$(basename -- $file)"
#   extension="${name##*.}"
#   filename="${name%.*}"

#   output="$OUTPUT_DIR/$filename.json"

#   lua5.3 parser.lua "$file" "$output" "fine-tuning-data"
#   echo "$file -> $output"
# done
