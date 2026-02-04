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

## Profiling And Error Recovery

Profiling uses Crystal-native timing and GC stats:

```
crystal run src/lrama/main.cr -- --profile=memory sample/calc.y -o sample/calc_parser.cr
```

This prints lines like `profile.time total=...` and `profile.memory.*` deltas to STDERR.
For call-stack profiling, use an external profiler and enable the flag for a hint:

```
crystal run src/lrama/main.cr -- --profile=call-stack sample/calc.y -o sample/calc_parser.cr
```

Error recovery is controlled at codegen time:

```
crystal run src/lrama/main.cr -- -e sample/calc.y -o sample/calc_parser.cr
```

## Lexer Tuning

By default the generated lexer uses fast tables and a byte-slice loop. For very
large DFAs, you can opt into more compact tables or a keyword trie:

```
crystal run src/lrama/main.cr -- -Dlexer.row_dedup=true sample/calc.y -o sample/calc_parser.cr
crystal run src/lrama/main.cr -- -Dlexer.keyword_trie=true sample/calc.y -o sample/calc_parser.cr
```

These settings trade a bit of speed for memory savings on large lexers.

For quick comparisons, use the microbench harness:

```
crystal run --release bench/bench.cr
LRAMA_BENCH_GRAMMAR=path/to/grammar.y crystal run --release bench/bench.cr
```

## Layout

- `src/` - Crystal implementation
- `spec/` - Crystal specs and fixtures
- `docs/` - Architecture notes
- `lrama/` - Ruby lrama submodule for reference
- `racc/` - Ruby racc submodule for reference

## Submodules

Update the Ruby submodules via Make targets:

```
make update_lrama
make update_racc
make update_submodules
```

## Docs

- `docs/architecture.md` - Design overview
- `docs/migration.md` - Crystal usage and migration guidance

## Examples

- `examples/sql.y` - SQL SELECT grammar using the lexer DSL and Crystal runtime.
