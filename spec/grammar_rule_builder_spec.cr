require "./spec_helper"

private def rule_builder_location
  grammar_file = Lrama::Lexer::GrammarFile.new("rule_builder.y", "%%")
  Lrama::Lexer::Location.new(
    grammar_file: grammar_file,
    first_line: 1,
    first_column: 0,
    last_line: 1,
    last_column: 1
  )
end

describe Lrama::Grammar::RuleBuilder do
  it "numbers references and marks referred rhs" do
    location = rule_builder_location
    resolver = Lrama::Grammar::Parameterized::Resolver.new
    rule_counter = Lrama::Grammar::Counter.new(0)
    midrule_counter = Lrama::Grammar::Counter.new(1)
    builder = Lrama::Grammar::RuleBuilder.new(rule_counter, midrule_counter, resolver)

    builder.lhs = Lrama::Lexer::Token::Ident.new("expr", location: location)
    builder.add_rhs(Lrama::Lexer::Token::Ident.new("a", location: location))
    builder.add_rhs(Lrama::Lexer::Token::Ident.new("b", location: location))
    builder.user_code = Lrama::Lexer::Token::UserCode.new("$1", location: location)
    builder.complete_input
    builder.setup_rules

    builder.rhs.first.referred?.should be_true
    builder.rules.size.should eq 1
  end
end
