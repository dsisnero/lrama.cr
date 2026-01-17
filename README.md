# Lrama.cr

Crystal port of Ruby's `lrama` parser generator. This project aims to emit
pure Crystal parsers (no Ruby or C extension runtime) while keeping the
generated parsers fast and memory efficient.

## Status

Early scaffolding: lexer, fixtures, and specs are in place to validate token
streams and locations. Parser generation is not implemented yet.

## Development

Requirements:

- Crystal 1.9+
- Ameba (dev dependency)

Useful commands:

```bash
crystal tool format src spec
ameba src spec
crystal spec
```

## Layout

- `src/` - Crystal implementation
- `spec/` - Crystal specs and fixtures
- `docs/` - Architecture notes
- `lrama/` - Ruby lrama submodule for reference
