#!/usr/bin/env bash

mkdir -p temp

filepath=$1
filename=$(basename "$filepath")
filename="${filename%.*}"

# Input file: -i in.txt
shift
if [ "$1" == "-i" ]; then
  input="$2"
  shift
  shift
else
  input="/dev/null"
fi

moon run src/bin --debug -- --wasm "$filepath" -o "temp/${filename}.wat" || exit $?
wasm-tools parse "temp/${filename}.wat" -o "temp/${filename}.wasm" || exit $?

if [ "$1" == "-o" ]; then
  cat "$input" | node ./wasm_rt/runtime.mjs "temp/${filename}.wasm" > "temp/${filename}.out"
else
  cat "$input" | node ./wasm_rt/runtime.mjs "temp/${filename}.wasm"
fi
