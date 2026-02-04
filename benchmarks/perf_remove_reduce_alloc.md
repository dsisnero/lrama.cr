# Performance Result: Remove Reduce-Time Allocations

Date: 2026-02-04

## Change

- Remove reduce-time array allocations by indexing into stacks (`stack_base`) and popping values in-place.

## Setup

- Built via `make samples-all` (Crystal builds use `--release`).
- Input: `samples/sql_input_big.sql` (200x `samples/sql_input.sql`).

## Command

```
hyperfine --warmup 3 --min-runs 20 \
  "cat samples/sql_input_big.sql | temp/sql_parser >/dev/null" \
  "cat samples/sql_input_big.sql | temp/sql_c >/dev/null"
```

## Results

```
Benchmark 1: cat samples/sql_input_big.sql | temp/sql_parser >/dev/null
  Time (mean ± σ):      11.3 ms ±   1.0 ms    [User: 6.3 ms, System: 8.3 ms]
  Range (min … max):     9.2 ms …  16.9 ms    112 runs

Benchmark 2: cat samples/sql_input_big.sql | temp/sql_c >/dev/null
  Time (mean ± σ):      12.2 ms ±   1.7 ms    [User: 6.1 ms, System: 8.7 ms]
  Range (min … max):     9.6 ms …  24.2 ms    123 runs

Summary
  cat samples/sql_input_big.sql | temp/sql_parser >/dev/null ran
    1.08 ± 0.18 times faster than cat samples/sql_input_big.sql | temp/sql_c >/dev/null

  Warning: Statistical outliers were detected.
```
