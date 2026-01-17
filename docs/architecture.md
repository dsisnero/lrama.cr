# Lrama Crystal Port Architecture

## Goals

- Generate pure Crystal parsers (no C or Ruby extension runtime).
- Preserve lrama grammar semantics and CLI behavior where practical.
- Keep generated parsers performant via compact tables and tight hot loops.
- Make the Crystal runtime reusable and stable across generated parsers.

## Non-goals

- Perfect feature parity on day one with every Ruby-specific integration.
- Supporting Ruby C extension output or Ruby runtime hooks.

## High-level Components

1. CLI and Options
   - Parse CLI args, load grammar file, drive pipeline.
2. Grammar Frontend
   - Lexer + parser for lrama grammar files.
   - Build Grammar AST: symbols, rules, precedence, directives.
3. Grammar Analysis
   - Expand parameterized rules, resolve %inline, build symbol tables.
4. LR State Construction
   - Build LR(1)/LALR(1) automaton, compute lookaheads.
   - Resolve conflicts using precedence and explicit directives.
5. Code Generation
   - Emit Crystal source with embedded tables and runtime hooks.
6. Crystal Runtime
   - Parser base class, lexer interface, error recovery utilities.

## Data Flow

Grammar file -> Lexer/Parser -> Grammar AST -> Analysis -> LR States
-> Tables/Actions -> Crystal Codegen -> Generated Parser + Runtime

## Crystal Runtime Design

- Base class `Lrama::Runtime::Parser(T)` where `T` is semantic value type.
- Lexer interface yields token id + semantic value + location.
- Parse loop uses precomputed action/goto tables and a value stack.
- Error recovery modeled after lrama behavior (panic + expected tokens).
- Hooks for user actions, typed semantic values, and locations.

## Codegen Output Structure

- Module with:
  - Token id constants.
  - Rule id constants and metadata (lhs, rhs length).
  - Action table and goto table (Int32 arrays).
  - Optional compressed tables for memory reduction.
- Parser class extends runtime base and installs tables.
- User action methods injected in a namespaced module.

## Performance Strategy

- Use `Int32` arrays and tight loops; avoid allocations in hot paths.
- Store tables as `StaticArray` or `Slice` when size is fixed.
- Optional table compression (row displacement or sparse encoding).
- Provide `--release` benchmark guidance and microbench harness.

## Compatibility Notes

- Keep grammar directives aligned with lrama (`parser.y` semantics).
- Maintain error messages/diagnostics format where possible.
- Provide a migration guide for Ruby users moving to Crystal.
