module Lrama
  module Stdlib
    STDLIB_PATH = File.expand_path(File.join(__DIR__, "grammar", "stdlib.y"))

    def self.merge_into(grammar : Grammar)
      return if grammar.no_stdlib?

      stdlib_text = File.read(STDLIB_PATH)
      stdlib_file = Lexer::GrammarFile.new(STDLIB_PATH, stdlib_text)
      stdlib_grammar = GrammarParser.new(Lexer.new(stdlib_file)).parse

      grammar.prepend_parameterized_rules(stdlib_grammar.parameterized_rules)
    end
  end
end
