require "./spec_helper"

describe Lrama::Grammar do
  it "normalizes rules and assigns lhs/rhs symbols" do
    text = [
      "%token NUMBER",
      "%%",
      "expr: NUMBER ;",
      "%%",
      "",
    ].join("\n")
    grammar_file = Lrama::Lexer::GrammarFile.new("normalize.y", text)
    lexer = Lrama::Lexer.new(grammar_file)
    parser = Lrama::GrammarParser.new(lexer)
    grammar = parser.parse

    grammar.append_special_symbols
    grammar.normalize_rules
    grammar.collect_symbols
    grammar.set_lhs_and_rhs
    grammar.fill_default_precedence
    grammar.fill_symbols
    grammar.fill_sym_to_rules

    grammar.rules.size.should be > 0
    grammar.rules.first.lhs.should_not be_nil
    grammar.rules.first.lhs.try(&.nterm?).should be_true
    grammar.sym_to_rules.size.should be > 0
  end
end
