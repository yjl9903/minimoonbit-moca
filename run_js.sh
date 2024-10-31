#!/usr/bin/env bash

mkdir -p temp

filepath=$1
filename=$(basename "$filepath")
filename="${filename%.*}"

moon run src/bin/main.mbt --debug -- --js "$filepath" -o "temp/${filename}.mjs" || exit $?

if [ "$2" == "-o" ]; then
  echo '' | node ./js_rt/runtime.mjs "temp/${filename}.mjs" > "temp/${filename}.out"
else
  echo '' | node ./js_rt/runtime.mjs "temp/${filename}.mjs"
fi
