require "./spec_helper"

private def parse_grammar(text : String)
  grammar_file = Lrama::Lexer::GrammarFile.new("warnings.y", text)
  parser = Lrama::GrammarParser.new(Lrama::Lexer.new(grammar_file))
  parser.parse
end

describe Lrama::Warnings do
  it "emits implicit empty warnings" do
    grammar = parse_grammar([
      "%%",
      "expr: ;",
      "%%",
      "",
    ].join("\n"))

    output = IO::Memory.new
    logger = Lrama::Logger.new(output)
    warnings = Lrama::Warnings.new(logger, true)

    warnings.warn(grammar, Lrama::States.new(grammar))

    output.to_s.includes?("warning: warning: empty rule without %empty").should be_true
  end

  it "emits name conflicts for parameterized rules" do
    grammar = parse_grammar([
      "%token list",
      "%rule list(X): X",
      "%%",
      "expr: list(term);",
      "%%",
      "",
    ].join("\n"))
    grammar.prepare

    output = IO::Memory.new
    logger = Lrama::Logger.new(output)
    warnings = Lrama::Warnings.new(logger, true)

    warnings.warn(grammar, Lrama::States.new(grammar))

    output.to_s.includes?("warning: warning: parameterized rule name \"list\" conflicts with symbol name").should be_true
  end

  it "emits useless precedence warnings" do
    grammar = parse_grammar([
      "%left PLUS",
      "%token PLUS",
      "%%",
      "expr: PLUS ;",
      "%%",
      "",
    ].join("\n"))
    grammar.prepare

    output = IO::Memory.new
    logger = Lrama::Logger.new(output)
    warnings = Lrama::Warnings.new(logger, true)

    warnings.warn(grammar, Lrama::States.new(grammar))

    output.to_s.includes?("Precedence PLUS").should be_true
  end
end
