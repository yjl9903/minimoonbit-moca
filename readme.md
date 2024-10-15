# MiniMoonBit

## Quickstart

Install moonbit VS Code extension.

Install moonbit compiler.

```bash
curl -fsSL https://cli.moonbitlang.cn/install/unix.sh | bash -s minimoonbit
```

Then

```bash
moon update
moon install
```

## Test

Install [Just](https://github.com/casey/just).

```bash
just test-parse
just test-typecheck
just test-knf
just test-closure
```

## Reference

- Original repo: [minimoonbit-public](https://github.com/moonbitlang/minimoonbit-public/tree/main)
