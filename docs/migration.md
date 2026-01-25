# Crystal Usage And Migration Guide

This document summarizes how to run the Crystal port of `lrama`, what is
implemented today, and how to migrate from the Ruby version.

## Running The Crystal CLI

Use Crystal to run the CLI directly from source:

```
crystal run src/lrama/main.cr -- --help
```

If you want a faster build for repeated runs:

```
crystal build --release -o bin/lrama src/lrama/main.cr
./bin/lrama --help
```

## Current Capabilities

- Lexer + grammar parser for `.y` files.
- Grammar analysis, LALR state generation, and conflict reporting.
- Crystal code generation with compressed tables and action translation.
- Optional report output (`--report` and `--report-file`).
- Diagram output renders a textual HTML summary of rules (`--diagram`).

## Gaps And Differences From Ruby Lrama

- The default skeleton is `crystal/parser.ecr`; Ruby C skeletons are not supported
  in the Crystal CLI yet.
- Diagram output uses rule text rather than railroad SVGs.
- Some CLI behaviors are present but are no-ops until codegen completes.

## Migration Tips

1. Start by running the Crystal CLI against existing grammars to validate
   lexer and parser behavior (`--report=states,conflicts` is useful).
2. Compare conflicts and warnings between Ruby and Crystal outputs.
3. Keep using Ruby-generated parsers in production until Crystal codegen
   and runtime reach parity.

## Reporting Issues

Include the grammar file and the Crystal command used. If behavior differs
from Ruby, note the Ruby version and provide any `.output` report for
comparison.
