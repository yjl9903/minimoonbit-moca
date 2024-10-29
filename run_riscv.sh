#!/usr/bin/env bash

filepath=$1
filename=$(basename "$filepath")
filename="${filename%.*}"

moon run src/bin/main.mbt -- "$filepath" -o "temp/${filename}.s" || exit $?

zig build-exe -target riscv64-linux "-femit-bin=temp/${filename}" \
  "temp/${filename}.s" /runtime/riscv_rt/zig-out/lib/libmincaml.a \
  -O Debug -fno-strip -mcpu=baseline_rv64 || exit $?

./rvlinux -n "temp/${filename}"
