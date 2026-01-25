# Benchmarks

Run the microbench harness with Crystal in release mode:

```
crystal run --release bench/bench.cr
```

The script benchmarks:

- Lexer tokenization of `lrama/parser.y`
- Grammar parsing + preparation
- State construction
- Runtime parser loop for a minimal hand-coded grammar
