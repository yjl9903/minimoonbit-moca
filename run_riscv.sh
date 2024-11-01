#!/usr/bin/env bash

mkdir -p temp
if [ ! -e "riscv_rt/zig-out/lib/libmincaml.a" ]; then
  ./build_riscvrt.sh
fi

filepath=$1
filename=$(basename "$filepath")
filename="${filename%.*}"

moon run src/bin/main.mbt -- "$filepath" -o "temp/${filename}.s" || exit $?

zig build-exe -target riscv64-linux "-femit-bin=temp/${filename}" \
  "temp/${filename}.s" "riscv_rt/zig-out/lib/libmincaml.a" \
  -O Debug -fno-strip -mcpu=baseline_rv64 || exit $?

if [ "$2" == "-o" ]; then
  ./rvlinux -n "temp/${filename}" > "temp/${filename}.out"
else
  ./rvlinux -n "temp/${filename}"
fi
