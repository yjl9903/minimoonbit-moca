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

moon run src/bin/main.mbt --debug -- --js "$filepath" -o "temp/${filename}.mjs" || exit $?

if [ "$1" == "-o" ]; then
  cat "$input" | node ./js_rt/runtime.mjs "temp/${filename}.mjs" > "temp/${filename}.out"
else
  cat "$input" | node ./js_rt/runtime.mjs "temp/${filename}.mjs"
fi
