module Lrama
  class CLI
    def self.run(args = ARGV, io = STDOUT, err = STDERR)
      option_parser = Lrama::OptionParser.new
      begin
        options = option_parser.parse(args)
      rescue ex : ::OptionParser::InvalidOption | ::OptionParser::MissingOption | Lrama::OptionParser::OptionError
        err.puts ex.message
        err.puts option_parser
        return 1
      end

      begin
        text = options.y.read
        options.y.close unless options.y == STDIN

        grammar_file = Lexer::GrammarFile.new(options.grammar_file, text)
        grammar = GrammarParser.new(Lexer.new(grammar_file)).parse
        Stdlib.merge_into(grammar)
        grammar.prepare
        grammar.validate!

        tracer = Tracer.new(err, **(options.trace_opts || {} of Symbol => Bool))
        tracer.enable_duration
        states = States.new(grammar, tracer)
        states.compute
        states.compute_ielr if grammar.ielr_defined?

        if report_file = options.report_file
          reporter = Reporter.new(**(options.report_opts || {} of Symbol => Bool))
          File.open(report_file, "w+") do |file|
            reporter.report(file, states)
          end
        end

        if options.diagram?
          File.open(options.diagram_file, "w+") do |file|
            Diagram.render(io: file, grammar: grammar)
          end
        end

        tables = TableBuilder.new(states, grammar).to_tables
        class_name = parser_class_name(options.outfile)
        File.open(options.outfile, "w+") do |file|
          Generator::Crystal.new(grammar, tables, class_name).render(file)
        end

        warnings = Warnings.new(Logger.new, options.warnings?)
        warnings.warn(grammar, states)
      rescue ex
        err.puts ex.message
        return 1
      end

      0
    end

    private def self.parser_class_name(output_path : String)
      base = File.basename(output_path, File.extname(output_path))
      parts = base.split(/[^A-Za-z0-9]+/).reject(&.empty?)
      name = parts.map(&.capitalize).join
      name.empty? ? "Parser" : name
    end
  end
end
