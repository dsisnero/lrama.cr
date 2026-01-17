require "../../spec_helper"

describe Lrama::Lexer::Token::UserCode do
  it "returns references in user code" do
    grammar_file = Lrama::Lexer::GrammarFile.new("test.y", "")
    location = Lrama::Lexer::Location.new(
      grammar_file: grammar_file,
      first_line: 1,
      first_column: 0,
      last_line: 1,
      last_column: 2
    )

    references = Lrama::Lexer::Token::UserCode.new(" $$ ", location).references
    references.size.should eq 1
    references[0].should eq Lrama::Grammar::Reference.new(
      type: :dollar,
      name: "$",
      ex_tag: nil,
      first_column: 1,
      last_column: 3
    )

    references = Lrama::Lexer::Token::UserCode.new(" $<long>$ ", location).references
    references.size.should eq 1
    references[0].should eq Lrama::Grammar::Reference.new(
      type: :dollar,
      name: "$",
      ex_tag: Lrama::Lexer::Token::Tag.new("<long>", location),
      first_column: 1,
      last_column: 9
    )

    references = Lrama::Lexer::Token::UserCode.new(" $1 ", location).references
    references.size.should eq 1
    references[0].should eq Lrama::Grammar::Reference.new(
      type: :dollar,
      number: 1,
      index: 1,
      ex_tag: nil,
      first_column: 1,
      last_column: 3
    )

    references = Lrama::Lexer::Token::UserCode.new(" $<long>1 ", location).references
    references.size.should eq 1
    references[0].should eq Lrama::Grammar::Reference.new(
      type: :dollar,
      number: 1,
      index: 1,
      ex_tag: Lrama::Lexer::Token::Tag.new("<long>", location),
      first_column: 1,
      last_column: 9
    )

    references = Lrama::Lexer::Token::UserCode.new(" $foo ", location).references
    references.size.should eq 1
    references[0].should eq Lrama::Grammar::Reference.new(
      type: :dollar,
      name: "foo",
      ex_tag: nil,
      first_column: 1,
      last_column: 5
    )

    references = Lrama::Lexer::Token::UserCode.new(" $<long>foo ", location).references
    references.size.should eq 1
    references[0].should eq Lrama::Grammar::Reference.new(
      type: :dollar,
      name: "foo",
      ex_tag: Lrama::Lexer::Token::Tag.new("<long>", location),
      first_column: 1,
      last_column: 11
    )

    references = Lrama::Lexer::Token::UserCode.new(" $[expr.right] ", location).references
    references.size.should eq 1
    references[0].should eq Lrama::Grammar::Reference.new(
      type: :dollar,
      name: "expr.right",
      ex_tag: nil,
      first_column: 1,
      last_column: 14
    )

    references = Lrama::Lexer::Token::UserCode.new(" $<long>[expr.right] ", location).references
    references.size.should eq 1
    references[0].should eq Lrama::Grammar::Reference.new(
      type: :dollar,
      name: "expr.right",
      ex_tag: Lrama::Lexer::Token::Tag.new("<long>", location),
      first_column: 1,
      last_column: 20
    )

    references = Lrama::Lexer::Token::UserCode.new(" @$ ", location).references
    references.size.should eq 1
    references[0].should eq Lrama::Grammar::Reference.new(
      type: :at,
      name: "$",
      ex_tag: nil,
      first_column: 1,
      last_column: 3
    )

    references = Lrama::Lexer::Token::UserCode.new(" @1 ", location).references
    references.size.should eq 1
    references[0].should eq Lrama::Grammar::Reference.new(
      type: :at,
      number: 1,
      index: 1,
      ex_tag: nil,
      first_column: 1,
      last_column: 3
    )

    references = Lrama::Lexer::Token::UserCode.new(" @foo ", location).references
    references.size.should eq 1
    references[0].should eq Lrama::Grammar::Reference.new(
      type: :at,
      name: "foo",
      ex_tag: nil,
      first_column: 1,
      last_column: 5
    )

    references = Lrama::Lexer::Token::UserCode.new(" @[expr.right] ", location).references
    references.size.should eq 1
    references[0].should eq Lrama::Grammar::Reference.new(
      type: :at,
      name: "expr.right",
      ex_tag: nil,
      first_column: 1,
      last_column: 14
    )
  end
end
