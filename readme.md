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

## Test

Install [Just](https://github.com/casey/just?tab=readme-ov-file#packages).

```bash
just test-parse
just test-typecheck
just test-knf
just test-closure
```

## Reference

- Original Repository: [minimoonbit-public](https://github.com/moonbitlang/minimoonbit-public/tree/main)
