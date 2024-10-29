#!/usr/bin/env bash

mkdir -p temp

filepath=$1
filename=$(basename "$filepath")
filename="${filename%.*}"

moon run src/bin --debug -- --wasm "$filepath" -o "temp/${filename}.wat" || exit $?
wasm-tools parse "temp/${filename}.wat" -o "temp/${filename}.wasm" || exit $?

if [ "$2" == "-o" ]; then
  echo '' | node ./wasm_rt/runtime.mjs "temp/${filename}.wasm" > "temp/${filename}.out"
else
  echo '' | node ./wasm_rt/runtime.mjs "temp/${filename}.wasm"
fi
