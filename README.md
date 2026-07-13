# Zis

A tiny tool for better control over your Zig projects.

## Prerequisites

- **[Zig](https://ziglang.org/download)** (master)
- [Only](https://github.com/KercyDing/only) (task runner if you like)

## Usage

```bash
zig build run -- fetch https:/code.kercy666.com/Kercy/zis
# or:
# only r fetch https:/code.kercy666.com/Kercy/zis
```

Yeah actually it just gets the header like `curl -I`.

## A Few Thoughts

I heard about the project called [Ziggy](https://github.com/kristoff-it/ziggy), and it’s perfect for my Zis.

So I built [libcommand](libcommand/README.md), a library which could build CLI with a easy `.ziggy`.

This project is still in its very early stages, and I feel joy to build it.

## LICENSE

[MIT](LICENSE)
