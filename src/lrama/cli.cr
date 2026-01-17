require "option_parser"

module Lrama
  class CLI
    def self.run(args = ARGV, io = STDOUT, err = STDERR)
      show_version = false
      show_help = false
      parser = OptionParser.new do |options|
        options.banner = "Usage: lrama [options] <grammar.y>"
        options.on("-v", "--version", "Print version") { show_version = true }
        options.on("-h", "--help", "Show help") { show_help = true }
      end

      begin
        parser.parse(args)
      rescue ex : OptionParser::InvalidOption
        err.puts ex.message
        err.puts parser
        return 1
      end

      if show_help
        io.puts parser
        return 0
      end

      if show_version
        io.puts "lrama #{Lrama::VERSION}"
        return 0
      end

      if args.empty?
        err.puts "error: missing grammar file"
        err.puts parser
        return 1
      end

      err.puts "error: Crystal port not implemented yet"
      1
    end
  end
end
