# Zis

A tiny tool for better control over your Zig projects.

## Prerequisites

- **[Zig](https://ziglang.org/download)** (>=`0.17.0-dev.1282+c0f9b51d8`)
- [Only](https://github.com/KercyDing/only) (task runner if you like)

## Usage

```bash
zig build run -- fetch https://code.kercy666.com/Kercy/zis.git --force
# or:
# only r fetch https://code.kercy666.com/Kercy/zis.git --force
```

Yeah actually it prints the message and does nothing...

## A Few Thoughts

I heard about the project called [Ziggy](https://github.com/kristoff-it/ziggy), and it’s perfect for my Zis.

So I built [libcommand](libcommand/README.md), a library which could build CLI with a easy `.ziggy`.

This project is still in its very early stages, and I feel joy to build it.

## LICENSE

[MIT](LICENSE)
