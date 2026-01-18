require "./spec_helper"

private def binding_location
  grammar_file = Lrama::Lexer::GrammarFile.new("binding.y", "%%")
  Lrama::Lexer::Location.new(
    grammar_file: grammar_file,
    first_line: 1,
    first_column: 0,
    last_line: 1,
    last_column: 1
  )
end

describe Lrama::Grammar::Binding do
  it "resolves parameterized args and concatenates names" do
    location = binding_location
    params = [] of Lrama::Lexer::Token::Base
    params << Lrama::Lexer::Token::Ident.new("X", location: location)
    params << Lrama::Lexer::Token::Ident.new("Y", location: location)

    args = [] of Lrama::Lexer::Token::Base
    args << Lrama::Lexer::Token::Ident.new("left", location: location)
    args << Lrama::Lexer::Token::Ident.new("right", location: location)
    binding = Lrama::Grammar::Binding.new(params, args)

    token = Lrama::Lexer::Token::InstantiateRule.new(
      "pair",
      location: location,
      args: params
    )

    binding.concatenated_args_str(token).should eq "pair_left_right"
    resolved = binding.resolve_symbol(token).as(Lrama::Lexer::Token::InstantiateRule)
    resolved.args.map(&.s_value).should eq ["left", "right"]
  end
end
