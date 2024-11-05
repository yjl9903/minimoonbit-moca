# MiniMoonBit

[![moonbit-check](https://github.com/yjl9903/minimoonbit-moca/actions/workflows/moonbit.yml/badge.svg)](https://github.com/yjl9903/minimoonbit-moca/actions/workflows/moonbit.yml)

Mini Moonbit implementation from 加力燃烧器.

## Quickstart

Install moonbit compiler.

```bash
curl -fsSL https://cli.moonbitlang.cn/install/unix.sh | bash -s minimoonbit
```

Install moonbit VS Code extension `moonbit.moonbit-lang`.

Then:

```bash
moon update
moon install
```

Optionally, build RISC-V simulator.

Make sure you have installed zig 0.13.0 ([here](https://github.com/ziglang/zig/wiki/Install-Zig-from-a-Package-Manager)) and cmake.

```bash
git submodule update --init --recursive
./build_rvlinux.sh
./build_riscvrt.sh
```

You will have `rvlinux` linked in the project root directory.

## Run

You can directly use the following scripts to run our MiniMoonbit implementation.

```bash
./run_riscv.sh test/test_src/print.mbt
./run_wasm.sh test/test_src/print.mbt
./run_js.sh test/test_src/print.mbt
./run_ssa.sh test/test_src/print.mbt
./run_machine_ir.sh test/test_src/print.mbt
```

Run with RSIC-V backend manually.

```bash
moon run src/bin/main.mbt -- <input> -o <output>
zig build-exe -target riscv64-linux -femit-bin=<exe_file> \
  <output> /runtime/riscv_rt/zig-out/lib/libmincaml.a \
  -O Debug -fno-strip -mcpu=baseline_rv64
rvlinux -n <exe_file>
```

Run with JS backend manually.

```bash
moon run src/bin/main.mbt -- --js <input> -o <output>.mjs
node ./js_rt/runtime.mjs <output>.mjs
```

Run with WASM backend manually.

```bash
moon run src/bin/main.mbt -- --wasm <input> -o <output>.wat
wasm-tools parse <output>.wat -o <output>.wasm
node ./wasm_rt/runtime.mjs <output>.wasm
```

## Test

Install [Just](https://github.com/casey/just?tab=readme-ov-file#packages).

```bash
just test-parse
just test-typecheck
just test-knf
just test-closure
just test-js
just test-wasm
just test-riscv
```

## Reference

- Original Repository: [minimoonbit-public](https://github.com/moonbitlang/minimoonbit-public/tree/main)
