Benchmark 1: cat samples/sql_input_big.sql | temp/sql_parser >/dev/null
  Time (mean ± σ):      34.2 ms ±   4.9 ms    [User: 18.6 ms, System: 24.2 ms]
  Range (min … max):    28.6 ms …  44.4 ms    43 runs

Benchmark 2: cat samples/sql_input_big.sql | temp/sql_c >/dev/null
  Time (mean ± σ):      24.4 ms ±   3.0 ms    [User: 12.8 ms, System: 17.1 ms]
  Range (min … max):    20.0 ms …  31.5 ms    52 runs

Summary
  cat samples/sql_input_big.sql | temp/sql_c >/dev/null ran
    1.40 ± 0.27 times faster than cat samples/sql_input_big.sql | temp/sql_parser >/dev/null
