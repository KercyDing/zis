# libcommand

A Zig library to build CLI with a easy `.ziggy`.

## How Does It Work

The `command-codegen` build artifact parses a `.ziggy` file and generates a
Zig module containing the CLI schema. Pass the generated `cli` value to
`command.Generate` to create the strongly typed parser.

## LICENSE

[MIT](LICENSE)
