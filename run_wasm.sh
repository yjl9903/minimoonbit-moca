#!/usr/bin/env bash

filepath=$1
filename=$(basename "$filepath")
filename="${filename%.*}"

moon run src/bin --debug -- --wasm "$filepath" -o "temp/${filename}.wat"
wasm-tools parse "temp/${filename}.wat" -o "temp/${filename}.wasm"

if [ -z "$2" ]; then
  echo '' | node ./wasm_rt/runtime.mjs "temp/${filename}.wasm"
else
  echo '' | node ./wasm_rt/runtime.mjs "temp/${filename}.wasm" > "$2"
fi
