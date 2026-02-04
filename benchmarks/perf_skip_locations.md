# Performance Result: Skip Location Stack When Unused

Date: 2026-02-04

## Change

- Add HAS_LOCATIONS and avoid pushing/popping locations and computing reduce_location when not used.

## Setup

- Generated `samples/sql_parser.cr` and built with `--release` via `make run_benchmark`.
- Input: `samples/sql_input_big.sql` (200x `samples/sql_input.sql`).

## Command

```
hyperfine --warmup 5 --min-runs 30 \
  "cat samples/sql_input_big.sql | temp/sql_parser >/dev/null" \
  "cat samples/sql_input_big.sql | temp/sql_c >/dev/null"
```

## Results

```
Benchmark 1: cat samples/sql_input_big.sql | temp/sql_parser >/dev/null
  Time (mean ± σ):      11.1 ms ±   0.7 ms    [User: 6.4 ms, System: 8.3 ms]
  Range (min … max):     9.4 ms …  12.9 ms    120 runs

Benchmark 2: cat samples/sql_input_big.sql | temp/sql_c >/dev/null
  Time (mean ± σ):      11.0 ms ±   0.7 ms    [User: 5.5 ms, System: 8.2 ms]
  Range (min … max):     9.0 ms …  12.4 ms    119 runs

Summary
  cat samples/sql_input_big.sql | temp/sql_c >/dev/null ran
    1.01 ± 0.09 times faster than cat samples/sql_input_big.sql | temp/sql_parser >/dev/null
```
