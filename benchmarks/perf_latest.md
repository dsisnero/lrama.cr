Benchmark 1: cat samples/sql_input_big.sql | temp/sql_parser >/dev/null
  Time (mean ± σ):      10.6 ms ±   0.7 ms    [User: 6.2 ms, System: 8.1 ms]
  Range (min … max):     8.5 ms …  12.8 ms    118 runs

Benchmark 2: cat samples/sql_input_big.sql | temp/sql_c >/dev/null
  Time (mean ± σ):      10.6 ms ±   0.9 ms    [User: 5.4 ms, System: 7.9 ms]
  Range (min … max):     8.5 ms …  14.1 ms    103 runs

Summary
  cat samples/sql_input_big.sql | temp/sql_parser >/dev/null ran
    1.00 ± 0.10 times faster than cat samples/sql_input_big.sql | temp/sql_c >/dev/null
