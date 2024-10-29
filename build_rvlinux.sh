#!/usr/bin/env bash

if [ ! -e "libriscv/emulator/.build/rvlinux" ]; then
  pushd libriscv/emulator
  ./build.sh --native --64 -b -v
  popd
fi

ln -fs libriscv/emulator/.build/rvlinux .
