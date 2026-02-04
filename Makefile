.PHONY: build install spec spec-all spec-provider spec-provider-record spec-interactive clean format docs build-examples update_lrama update_racc update_submodules samples-crystal-gen samples-crystal-build samples-crystal-run samples-crystal samples-ruby-gen samples-ruby-build samples-ruby-run samples-ruby samples-all run_benchmark

# Crystal cache for faster builds
export CRYSTAL_CACHE_DIR := $(PWD)/.crystal-cache
export BEADS_DIR ?= $(PWD)/.beads

# Example source files and their output binaries
EXAMPLE_SOURCES := $(shell find examples -name '*.cr')
EXAMPLE_BINARIES := $(EXAMPLE_SOURCES:.cr=)
SAMPLES := calc json sql parse
CRYSTAL_SAMPLE_DIR := samples
RUBY_SAMPLE_DIR := lrama/sample
TMP_DIR := temp
BENCH_REPORT := benchmarks/perf_latest.md

CRYSTAL_SAMPLE_PARSERS := $(SAMPLES:%=$(CRYSTAL_SAMPLE_DIR)/%_parser.cr)
CRYSTAL_SAMPLE_BINS := $(SAMPLES:%=$(TMP_DIR)/%_parser)
RUBY_SAMPLE_CS := $(SAMPLES:%=$(TMP_DIR)/%.c)
RUBY_SAMPLE_BINS := $(SAMPLES:%=$(TMP_DIR)/%_c)

# Build the library (check for errors)
build:
	shards build

install:
	GIT_CONFIG_GLOBAL=/dev/null shards install

update:
	GIT_CONFIG_GLOBAL=/dev/null shards update

update_lrama:
	git submodule update --remote --init lrama

update_racc:
	git submodule update --remote --init racc

update_submodules:
	git submodule update --remote --init lrama racc

# Run all tests (excluding interactive)
spec:
	crystal spec

# Run all tests including interactive
spec-all:
	crystal spec

# Format all Crystal files
format:
	crystal tool format

# Generate documentation
docs:
	crystal docs

# Build all examples (output in examples/ directory)
build-examples: $(EXAMPLE_BINARIES)
	@echo "Built all examples in examples/"

examples/%: examples/%.cr
	crystal build $< -o $@

$(TMP_DIR):
	mkdir -p $(TMP_DIR)

samples-crystal-gen: $(CRYSTAL_SAMPLE_PARSERS)
	@echo "Generated Crystal sample parsers"

samples-crystal-build: $(TMP_DIR) $(CRYSTAL_SAMPLE_BINS)
	@echo "Built Crystal sample binaries"

samples-crystal-run: samples-crystal-build
	@printf "1\n1+2*3\n(1+2)*3\n" | $(TMP_DIR)/calc_parser
	@cat $(CRYSTAL_SAMPLE_DIR)/json_input.txt | $(TMP_DIR)/json_parser
	@printf '{"foo": invalid }' | $(TMP_DIR)/json_parser || true
	@cat $(CRYSTAL_SAMPLE_DIR)/sql_input.sql | $(TMP_DIR)/sql_parser
	@printf "2+3*4" | $(TMP_DIR)/parse_parser
	@echo "Ran Crystal sample binaries"

samples-crystal: samples-crystal-gen samples-crystal-build samples-crystal-run

$(CRYSTAL_SAMPLE_DIR)/%_parser.cr: $(CRYSTAL_SAMPLE_DIR)/%.y
	CRYSTAL_CACHE_DIR=$(CRYSTAL_CACHE_DIR) crystal run src/lrama/main.cr -- $< -o $@

$(TMP_DIR)/%_parser: $(CRYSTAL_SAMPLE_DIR)/%_parser.cr
	CRYSTAL_CACHE_DIR=$(CRYSTAL_CACHE_DIR) crystal build --release $< -o $@

samples-ruby-gen: $(RUBY_SAMPLE_CS)
	@echo "Generated Ruby C sample parsers"

samples-ruby-build: $(TMP_DIR) $(RUBY_SAMPLE_BINS)
	@echo "Built Ruby C sample binaries"

samples-ruby-run: samples-ruby-build
	@printf "1\n1+2*3\n(1+2)*3\n" | $(TMP_DIR)/calc_c
	@printf '{"foo": 42, "bar": [1, 2, 3], "baz": {"qux": true}}' | $(TMP_DIR)/json_c
	@printf '{"foo": invalid }' | $(TMP_DIR)/json_c || true
	@printf "SELECT id, name FROM users WHERE age > 18 AND age < 32;\n" | $(TMP_DIR)/sql_c
	@printf "2+3*4" | $(TMP_DIR)/parse_c
	@echo "Ran Ruby C sample binaries"

samples-ruby: samples-ruby-gen samples-ruby-build samples-ruby-run

$(TMP_DIR)/%.c: $(RUBY_SAMPLE_DIR)/%.y
	ruby lrama/exe/lrama -d $< -o $@

$(TMP_DIR)/%_c: $(TMP_DIR)/%.c
	cc -Wall $< -I . -o $@

samples-all: samples-crystal samples-ruby

run_benchmark: $(TMP_DIR)
	@CRYSTAL_CACHE_DIR=$(CRYSTAL_CACHE_DIR) crystal run src/lrama/main.cr -- $(CRYSTAL_SAMPLE_DIR)/sql.y -o $(CRYSTAL_SAMPLE_DIR)/sql_parser.cr
	@CRYSTAL_CACHE_DIR=$(CRYSTAL_CACHE_DIR) crystal build --release $(CRYSTAL_SAMPLE_DIR)/sql_parser.cr -o $(TMP_DIR)/sql_parser
	@if [ ! -f samples/sql_input_big.sql ]; then \
		ruby -e 'src = File.read("samples/sql_input.sql"); File.write("samples/sql_input_big.sql", src * 200)'; \
	fi
	@hyperfine --warmup 5 --min-runs 30 \
	  "cat samples/sql_input_big.sql | $(TMP_DIR)/sql_parser >/dev/null" \
	  "cat samples/sql_input_big.sql | $(TMP_DIR)/sql_c >/dev/null" | tee $(BENCH_REPORT)

# Clean temporary files, logs, and build artifacts
clean:
	rm -rf temp/*
	rm -rf log/*
	rm -rf .crystal-cache
	rm -f *.dwarf
	rm -f $(EXAMPLE_BINARIES)
	@echo "Cleaned temp/, log/, .crystal-cache/, *.dwarf, and example binaries"

# Run benchmarks
benchmark:
	crystal run benchmarks/benchmark.cr --release

# Run a specific example
run-example:
	@if [ -z "$(EXAMPLE)" ]; then \
		echo "Usage: make run-example EXAMPLE=basic_example"; \
		echo "Available examples:"; \
		ls -1 examples/*.cr | xargs -n1 basename | sed 's/.cr$$//'; \
	else \
		crystal run examples/$(EXAMPLE).cr; \
	fi

# Help
help:
	@echo "Term2 - Crystal Terminal Library"
	@echo ""
	@echo "Available targets:"
	@echo "  build              - Build the library"
	@echo "  build-examples     - Build all examples (output in examples/)"
	@echo "  install            - Install dependencies"
	@echo "  update             - Update dependencies"
	@echo "  update_lrama       - Update ruby lrama submodule"
	@echo "  update_racc        - Update ruby racc submodule"
	@echo "  update_submodules  - Update ruby lrama and racc submodules"
	@echo "  spec               - Run tests (excluding interactive)"
	@echo "  format             - Format Crystal files"
	@echo "  docs               - Generate documentation"
	@echo "  clean              - Clean temp/, log/, cache, and built examples"
	@echo "  benchmark          - Run performance benchmarks"
	@echo "  run-example        - Run an example (EXAMPLE=name)"
	@echo "  samples-crystal    - Generate/build/run Crystal sample parsers"
	@echo "  samples-ruby       - Generate/build/run Ruby C sample parsers"
	@echo "  samples-all        - Run Crystal and Ruby sample suites"
	@echo "  run_benchmark      - Build samples and run hyperfine; write $(BENCH_REPORT)"
	@echo "  help               - Show this help"
