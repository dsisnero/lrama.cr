require "./spec_helper"

private def build_location(path : String)
  grammar_file = Lrama::Lexer::GrammarFile.new(path, "%%")
  Lrama::Lexer::Location.new(
    grammar_file: grammar_file,
    first_line: 1,
    first_column: 0,
    last_line: 1,
    last_column: 1
  )
end

describe Lrama::Grammar::Symbols::Resolver do
  it "adds terms and nterms and assigns token ids" do
    location = build_location("symbols.y")
    resolver = Lrama::Grammar::Symbols::Resolver.new

    term = resolver.add_term(Lrama::Lexer::Token::Char.new("'+'", location: location))
    nterm = resolver.add_nterm(Lrama::Lexer::Token::Ident.new("expr", location: location))

    resolver.fill_symbol_number

    term.term?.should be_true
    nterm.nterm?.should be_true
    term.token_id.should eq '+'.ord
    nterm.token_id.should eq 0
  end

  it "finds symbols by id and value" do
    location = build_location("symbols.y")
    resolver = Lrama::Grammar::Symbols::Resolver.new

    term_token = Lrama::Lexer::Token::Ident.new("TERM", location: location)
    resolver.add_term(term_token)

    resolver.find_symbol_by_id!(term_token).id.s_value.should eq "TERM"
    resolver.find_symbol_by_s_value!("TERM").id.s_value.should eq "TERM"
  end
end
