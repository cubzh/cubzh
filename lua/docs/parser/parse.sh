#!/bin/ash

INPUT_DIR="/modules"
OUTPUT_DIR="/www/modules"

rm -f "$OUTPUT_DIR"/*.json

for file in "$INPUT_DIR"/*.lua
do
  name="$(basename -- $file)"
  extension="${name##*.}"
  filename="${name%.*}"

  output="$OUTPUT_DIR/$filename.json"

  lua5.3 parser.lua "$file" "$output"
  echo "$file -> $output"
done
