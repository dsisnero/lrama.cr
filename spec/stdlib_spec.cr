require "./spec_helper"

describe Lrama::Stdlib do
  it "merges stdlib parameterized rules by default" do
    text = [
      "%%",
      "start: %empty ;",
      "%%",
      "",
    ].join("\n")
    grammar_file = Lrama::Lexer::GrammarFile.new("stdlib_merge.y", text)
    grammar = Lrama::GrammarParser.new(Lrama::Lexer.new(grammar_file)).parse

    Lrama::Stdlib.merge_into(grammar)

    grammar.parameterized_rules.any? { |rule| rule.name == "option" }.should be_true
  end

  it "skips stdlib merge when no_stdlib is set" do
    text = [
      "%%",
      "start: %empty ;",
      "%%",
      "",
    ].join("\n")
    grammar_file = Lrama::Lexer::GrammarFile.new("stdlib_skip.y", text)
    grammar = Lrama::GrammarParser.new(Lrama::Lexer.new(grammar_file)).parse
    grammar.no_stdlib = true

    Lrama::Stdlib.merge_into(grammar)

    grammar.parameterized_rules.should be_empty
  end
end
