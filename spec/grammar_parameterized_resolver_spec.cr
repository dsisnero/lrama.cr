require "./spec_helper"

private def resolver_location
  grammar_file = Lrama::Lexer::GrammarFile.new("resolver.y", "%%")
  Lrama::Lexer::Location.new(
    grammar_file: grammar_file,
    first_line: 1,
    first_column: 0,
    last_line: 1,
    last_column: 1
  )
end

describe Lrama::Grammar::Parameterized::Resolver do
  it "finds rules by name and argument count" do
    location = resolver_location
    resolver = Lrama::Grammar::Parameterized::Resolver.new
    rhs = Lrama::Grammar::Parameterized::Rhs.new
    params = [] of Lrama::Lexer::Token::Base
    params << Lrama::Lexer::Token::Ident.new("X", location: location)
    rule = Lrama::Grammar::Parameterized::Rule.new("list", params, [rhs])
    resolver.add_rule(rule)

    token = Lrama::Lexer::Token::InstantiateRule.new(
      "list",
      location: location,
      args: params
    )
    resolver.find_rule(token).should eq rule
  end

  it "raises for invalid argument count" do
    location = resolver_location
    resolver = Lrama::Grammar::Parameterized::Resolver.new
    rhs = Lrama::Grammar::Parameterized::Rhs.new
    params = [] of Lrama::Lexer::Token::Base
    params << Lrama::Lexer::Token::Ident.new("X", location: location)
    rule = Lrama::Grammar::Parameterized::Rule.new("list", params, [rhs])
    resolver.add_rule(rule)

    token = Lrama::Lexer::Token::InstantiateRule.new("list", location: location, args: [] of Lrama::Lexer::Token::Base)
    expect_raises(Exception, "Invalid number of arguments. `list`") do
      resolver.find_rule(token)
    end
  end
end
