require "option_parser"

require "./options"

module Lrama
  class OptionParser
    class OptionError < Exception
    end

    ALIASED_REPORTS   = {"cex" => "counterexamples"}
    REPORT_OPTION_MAP = {
      "states"          => :states,
      "itemsets"        => :itemsets,
      "lookaheads"      => :lookaheads,
      "solved"          => :solved,
      "counterexamples" => :counterexamples,
      "rules"           => :rules,
      "terms"           => :terms,
      "verbose"         => :verbose,
    }

    VALID_TRACES = %w[
      locations scan parse automaton bitsets closure
      grammar rules only-explicit-rules actions resource
      sets muscles tools m4-early m4 skeleton time ielr cex
    ]
    NOT_SUPPORTED_TRACES = %w[
      locations scan parse bitsets grammar resource
      sets muscles tools m4-early m4 skeleton ielr cex
    ]
    SUPPORTED_TRACES = VALID_TRACES - NOT_SUPPORTED_TRACES
    TRACE_OPTION_MAP = {
      "automaton"           => :automaton,
      "closure"             => :closure,
      "rules"               => :rules,
      "only-explicit-rules" => :only_explicit_rules,
      "actions"             => :actions,
      "time"                => :time,
    }

    VALID_PROFILES     = %w[call-stack memory]
    PROFILE_OPTION_MAP = {
      "call-stack" => :call_stack,
      "memory"     => :memory,
    }

    def self.parse(argv : Array(String)) : Options
      new.parse(argv)
    end

    def initialize
      @options = Options.new
      @trace = [] of String
      @report = [] of String
      @profile = [] of String
      @parser = nil.as(::OptionParser?)
    end

    def parse(argv : Array(String)) : Options
      parse_by_option_parser(argv)

      @options.trace_opts = validate_trace(@trace)
      @options.report_opts = validate_report(@report)
      @options.profile_opts = validate_profile(@profile)

      grammar_file = argv.shift?
      raise OptionError.new("File should be specified") unless grammar_file

      if grammar_file == "-"
        stdin_name = argv.shift?
        raise OptionError.new("File name for STDIN should be specified") unless stdin_name
        @options.grammar_file = stdin_name
        @options.y = STDIN
      else
        @options.grammar_file = grammar_file
        begin
          @options.y = File.open(grammar_file, "r")
        rescue ex
          raise OptionError.new(ex.message || "Failed to open file")
        end
      end

      if !@report.empty? && @options.report_file.nil?
        @options.report_file = default_report_file(@options.grammar_file)
      end

      if @options.header? && @options.header_file.nil?
        @options.header_file = default_header_file
      end

      @options
    end

    def to_s(io : IO) : Nil
      parser = @parser
      io << (parser ? parser.to_s : "")
    end

    def to_s : String
      parser = @parser
      parser ? parser.to_s : ""
    end

    private def parse_by_option_parser(argv : Array(String)) : Nil
      @parser = ::OptionParser.new(gnu_optional_args: true) do |parser|
        parser.banner = "Lrama is LALR (1) parser generator written in Crystal.\n\nUsage: lrama [options] FILE\n"
        parser.separator ""
        parser.separator "STDIN mode:"
        parser.separator "lrama [options] - FILE               read grammar from STDIN"
        parser.separator ""
        parser.separator "Tuning the Parser:"
        parser.on("-S FILE", "--skeleton=FILE", "specify the skeleton to use") { |value| @options.skeleton = value }
        parser.on("-t", "--debug", "display debugging outputs of internal parser") { @options.debug = true }
        parser.separator "                                     same as '-Dparse.trace'"
        parser.on("--locations", "enable location support") { @options.locations = true }
        parser.on("-D NAME[=VALUE]", "--define=NAME[=VALUE]", "similar to '%define NAME VALUE'") do |value|
          parse_define(value)
        end
        parser.separator ""
        parser.separator "Output:"
        parser.on("-H [FILE]", "--header [FILE]", "also produce a header file named FILE") do |value|
          @options.header = true
          @options.header_file = value unless value.empty?
        end
        parser.on("-d", "also produce a header file") { @options.header = true }
        parser.on("-r REPORTS", "--report=REPORTS", "also produce details on the automaton") do |value|
          @report = parse_csv(value)
        end
        parser.separator ""
        parser.separator "REPORTS is a list of comma-separated words that can include:"
        parser.separator "    states                           describe the states"
        parser.separator "    itemsets                         complete the core item sets with their closure"
        parser.separator "    lookaheads                       explicitly associate lookahead tokens to items"
        parser.separator "    solved                           describe shift/reduce conflicts solving"
        parser.separator "    counterexamples, cex             generate conflict counterexamples"
        parser.separator "    rules                            list unused rules"
        parser.separator "    terms                            list unused terminals"
        parser.separator "    verbose                          report detailed internal state and analysis results"
        parser.separator "    all                              include all the above reports"
        parser.separator "    none                             disable all reports"
        parser.on("--report-file=FILE", "also produce details on the automaton output to a file named FILE") do |value|
          @options.report_file = value
        end
        parser.on("-o FILE", "--output=FILE", "leave output to FILE") { |value| @options.outfile = value }
        parser.on("--trace=TRACES", "also output trace logs at runtime") { |value| @trace = parse_csv(value) }
        parser.separator ""
        parser.separator "TRACES is a list of comma-separated words that can include:"
        parser.separator "    automaton                        display states"
        parser.separator "    closure                          display states"
        parser.separator "    rules                            display grammar rules"
        parser.separator "    only-explicit-rules              display only explicit grammar rules"
        parser.separator "    actions                          display grammar rules with actions"
        parser.separator "    time                             display generation time"
        parser.separator "    all                              include all the above traces"
        parser.separator "    none                             disable all traces"
        parser.on("--diagram [FILE]", "generate a diagram of the rules") do |value|
          @options.diagram = true
          @options.diagram_file = value unless value.empty?
        end
        parser.on("--profile=PROFILES", "profiles parser generation parts") { |value| @profile = parse_csv(value) }
        parser.separator ""
        parser.separator "PROFILES is a list of comma-separated words that can include:"
        parser.separator "    call-stack                       use sampling call-stack profiler (stackprof gem)"
        parser.separator "    memory                           use memory profiler (memory_profiler gem)"
        parser.on("-v", "--verbose", "same as '--report=state'") { @report << "states" }
        parser.separator ""
        parser.separator "Diagnostics:"
        parser.on("-W", "--warnings", "report the warnings") { @options.warnings = true }
        parser.separator ""
        parser.separator "Error Recovery:"
        parser.on("-e", "enable error recovery") { @options.error_recovery = true }
        parser.separator ""
        parser.separator "Other options:"
        parser.on("-V", "--version", "output version information and exit") do
          puts "lrama #{Lrama::VERSION}"
          exit 0
        end
        parser.on("-h", "--help", "display this help and exit") do
          puts parser
          exit 0
        end
      end

      parser = @parser || raise "OptionParser not initialized"
      parser.parse(argv)
    end

    private def parse_define(value : String) : Nil
      parse_csv(value).each do |item|
        parts = item.split("=", 2)
        key = parts[0]
        val = parts[1]? || ""
        @options.define[key] = val
      end
    end

    private def parse_csv(value : String) : Array(String)
      value.split(",").reject(&.empty?)
    end

    private def validate_report(report : Array(String)) : Hash(Symbol, Bool)
      h = {:grammar => true} of Symbol => Bool
      return h if report.empty?
      return {} of Symbol => Bool if report == ["none"]
      if report == ["all"]
        REPORT_OPTION_MAP.each_value { |report_symbol| h[report_symbol] = true }
        return h
      end

      report.each do |entry|
        aliased = ALIASED_REPORTS[entry]? || entry
        report_symbol = REPORT_OPTION_MAP[aliased]?
        raise OptionError.new("Invalid report option \"#{entry}\".") unless report_symbol
        h[report_symbol] = true
      end

      h
    end

    private def validate_trace(trace : Array(String)) : Hash(Symbol, Bool)
      h = {} of Symbol => Bool
      return h if trace.empty? || trace == ["none"]
      all_traces = SUPPORTED_TRACES - ["only-explicit-rules"]
      if trace == ["all"]
        all_traces.each do |trace_name|
          trace_symbol = TRACE_OPTION_MAP[trace_name]? || raise OptionError.new("Invalid trace option \"#{trace_name}\".")
          h[trace_symbol] = true
        end
        return h
      end

      trace.each do |entry|
        if SUPPORTED_TRACES.includes?(entry)
          trace_symbol = TRACE_OPTION_MAP[entry]? || raise OptionError.new("Invalid trace option \"#{entry}\".")
          h[trace_symbol] = true
        else
          valid = SUPPORTED_TRACES.join(", ")
          raise OptionError.new("Invalid trace option \"#{entry}\".\nValid options are [#{valid}].")
        end
      end

      h
    end

    private def validate_profile(profile : Array(String)) : Hash(Symbol, Bool)
      h = {} of Symbol => Bool
      return h if profile.empty?

      profile.each do |entry|
        if VALID_PROFILES.includes?(entry)
          profile_symbol = PROFILE_OPTION_MAP[entry]? || raise OptionError.new("Invalid profile option \"#{entry}\".")
          h[profile_symbol] = true
        else
          valid = VALID_PROFILES.join(", ")
          raise OptionError.new("Invalid profile option \"#{entry}\".\nValid options are [#{valid}].")
        end
      end

      h
    end

    private def default_report_file(grammar_file : String) : String
      File.dirname(grammar_file) + "/" + File.basename(grammar_file, ".*") + ".output"
    end

    private def default_header_file : String
      source = @options.outfile
      source = @options.grammar_file if source.empty?
      File.dirname(source) + "/" + File.basename(source, ".*") + ".h"
    end
  end
end
