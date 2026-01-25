module Lrama
  class CLI
    def self.run(args = ARGV, io = STDOUT, err = STDERR)
      option_parser = Lrama::OptionParser.new
      begin
        option_parser.parse(args)
      rescue ex : ::OptionParser::InvalidOption | ::OptionParser::MissingOption | Lrama::OptionParser::OptionError
        err.puts ex.message
        err.puts option_parser
        return 1
      end

      err.puts "error: Crystal port not implemented yet"
      1
    end
  end
end
