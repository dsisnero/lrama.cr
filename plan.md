# Lrama.cr Port Plan

This plan maps Ruby lrama components to Crystal equivalents and sequences the
work needed to deliver a pure Crystal parser generator and runtime. It is
intentionally detailed to serve as the working checklist for the port.

## Phase 0: Project setup and parity scaffolding

1. Repository layout and tooling
   - Crystal shard structure, CLI entrypoint, and build wiring.
   - Lint/format setup with `ameba` and `crystal tool format`.
2. Spec harness and fixtures
   - Port lexer specs and fixtures from Ruby lrama.
   - Add spec helpers for parsing fixtures consistently.
3. Architecture and constraints
   - Document goals: no Ruby/C runtime, high performance, parity with lrama.
   - Capture known incompatibilities and acceptable deltas.

## Phase 1: Grammar frontend (lexer + parser) parity

References: `lrama/lib/lrama/lexer.rb`, `lrama/parser.y`, `lrama/lib/lrama/parser.rb`

1. Lexer parity
   - Ensure tokenization matches Ruby for:
     - Symbols, directives, tags, identifiers, integers, strings, chars.
     - Prologue/inline C blocks (`%{ %}` and `{ }`) with correct boundaries.
     - Line and column tracking, error formatting, and locations.
   - Implement `UserCode` reference scanning (see Ruby `lexer/token/user_code.rb`)
     and `Grammar::Reference` objects to support action validation.
   - Cover error cases: unexpected tokens, unexpected C code.
2. Grammar parser implementation
   - Replace `GrammarParser` token buckets with a real parser that consumes
     the lrama grammar language defined in `parser.y`.
   - Implement parsing actions for:
     - Prologue/epilogue (`%{ %}`, final `%%` section).
     - `%require`, `%define`, `%expect`, `%code`, `%union`.
     - `%token`, `%type`, `%nterm`, `%left`, `%right`, `%precedence`,
       `%nonassoc`, `%start`, `%inline`, `%empty`.
     - `%lex-param`, `%parse-param`, `%initial-action`, `%printer`,
       `%destructor`, `%error-token`.
     - `%after-shift`, `%before-reduce`, `%after-reduce`,
       `%after-shift-error-token`, `%after-pop-stack`.
   - Match Ruby error messages and raise locations identical to lrama.
3. Grammar model and semantic structures
   - Port `lrama/lib/lrama/grammar/*` into Crystal:
     - Symbols, symbol resolver, types, precedence, unions.
     - Rules, rule builders, parameterized rules and resolver.
     - Inline resolver and auxiliary containers.
     - Code nodes: initial action, printer, destructor, rule action, no-ref.
   - Add validation hooks to mirror Ruby semantics:
     - Conflicting declarations, redefined rules, implicit empty rules.
     - Tag/type mismatches, error token correctness.
4. Stdlib merge and preprocessing
   - Merge `lrama/lib/lrama/grammar/stdlib.y` when `%no-stdlib` is absent.
   - Implement parameterized rule expansion and inline resolution.
   - Keep `%define` and `%locations` behavior in sync with Ruby.

## Phase 2: State construction and analysis

References: `lrama/lib/lrama/states.rb`, `lrama/lib/lrama/state/*`,
`lrama/lib/lrama/digraph.rb`, `lrama/lib/lrama/bitmap.rb`

1. LR(1)/LALR(1) engine
   - Port core state item logic, closure, goto, and lookahead propagation.
   - Implement IELR state refinement (`States#compute_ielr`).
   - Match Ruby token numbering, rule numbering, and state IDs.
2. Conflict resolution and reporting
   - Port shift/reduce and reduce/reduce conflict resolution rules.
   - Implement resolved conflicts, inadequacy annotations, and warnings.
3. Counterexamples (optional but desirable)
   - Port `lrama/lib/lrama/counterexamples/*` to generate conflict traces.
   - Keep outputs aligned with Ruby for debugging parity.

## Phase 3: Runtime and Crystal code generation

References: `lrama/lib/lrama/output.rb`, `lrama/template/*`,
`doc/development/compressed_state_table/*`

1. Crystal runtime library
   - Parser base: state stack, semantic value stack, goto/action dispatch.
   - Error recovery behavior aligned with lrama (panic modes, expected tokens).
   - Token/value interfaces and location handling.
2. Code generator
   - Replace C/Ruby templates with Crystal code generation.
   - Emit tables for actions/gotos, default reductions, token/rule metadata.
   - Provide table compression strategies and optional flags.
   - Ensure generated code is fast and allocation-light.
3. Template and output integration
   - Replace `template/bison/*` with Crystal templates.
   - Ensure CLI writes `.cr` output (and optional headers if needed).

## Phase 4: CLI, options, and reporting

References: `lrama/lib/lrama/command.rb`, `lrama/lib/lrama/options.rb`,
`lrama/lib/lrama/reporter/*`, `lrama/lib/lrama/diagram.rb`

1. CLI and option parsing
   - Port all options and defaults from Ruby.
   - Match CLI behavior for `--report`, `--diagram`, `--trace`, `--locations`,
     `--output`, `--skeleton`, `--header`, `--debug`, and `--define`.
2. Reporter and diagnostics
   - Port reporters for grammar, rules, states, conflicts, precedence.
   - Preserve output formats for `.output` and report files.
3. Diagram generation
   - Port diagram output or provide Crystal-native equivalent.
4. Warnings and logging
   - Port warnings from `lrama/lib/lrama/warnings/*` and logger behavior.

## Phase 5: Performance and validation

1. Spec parity
   - Port critical Ruby specs for grammar parsing and state generation.
   - Add Crystal fixtures for edge cases (inline rules, parameterized rules).
2. Benchmarks
   - Add benchmark harness for lexer, parser generation, and runtime parsing.
   - Track memory usage and table sizes.
3. Hot path optimization
   - Tight loops and memory layout for action dispatch and stacks.
   - Avoid allocations in lexer/parser loops where possible.

## Deliverables and milestones

1. Phase 1 complete: grammar parsing parity and spec coverage.
2. Phase 2 complete: state generation and conflict resolution parity.
3. Phase 3 complete: Crystal runtime + codegen producing working parsers.
4. Phase 4 complete: CLI/reporting parity with lrama UX.
5. Phase 5 complete: benchmarks, performance tuning, and docs.

## Mapping: Ruby files to Crystal modules

- CLI/options: `lrama/lib/lrama/command.rb`, `lrama/lib/lrama/options.rb`
- Lexer/parser: `lrama/lib/lrama/lexer.rb`, `lrama/parser.y`
- Grammar model: `lrama/lib/lrama/grammar/*`
- State engine: `lrama/lib/lrama/states.rb`, `lrama/lib/lrama/state/*`
- Output/templates: `lrama/lib/lrama/output.rb`, `lrama/template/*`
- Reporter/diagnostics: `lrama/lib/lrama/reporter/*`, `lrama/lib/lrama/warnings/*`
- Tracing: `lrama/lib/lrama/tracer/*`
