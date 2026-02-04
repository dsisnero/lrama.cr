# Performance Baseline (Crystal vs Ruby C)

Date: 2026-02-04

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
  Time (mean ± σ):      10.9 ms ±   1.8 ms    [User: 6.4 ms, System: 8.2 ms]
  Range (min … max):     9.2 ms …  22.6 ms    133 runs

Benchmark 2: cat samples/sql_input_big.sql | temp/sql_c >/dev/null
  Time (mean ± σ):      12.6 ms ±   1.4 ms    [User: 6.1 ms, System: 8.8 ms]
  Range (min … max):     9.6 ms …  22.3 ms    130 runs

Summary
  cat samples/sql_input_big.sql | temp/sql_parser >/dev/null ran
    1.16 ± 0.23 times faster than cat samples/sql_input_big.sql | temp/sql_c >/dev/null

  Warning: Statistical outliers were detected.
```
