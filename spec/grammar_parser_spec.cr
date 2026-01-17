require "./spec_helper"

describe Lrama::GrammarParser do
  it "collects declarations, rules, and epilogue tokens" do
    path = File.join(__DIR__, "fixtures", "common", "basic.y")
    grammar_file = Lrama::Lexer::GrammarFile.new(path, File.read(path))
    lexer = Lrama::Lexer.new(grammar_file)
    parser = Lrama::GrammarParser.new(lexer)
    grammar = parser.parse

    grammar.prologue.should eq "\n// Prologue\n"
    grammar.required?.should be_true
    grammar.expect.should eq 0
    grammar.define["api.pure"].should be_nil
    grammar.define["parse.error"].should eq "verbose"
    grammar.define["api.prefix"].should eq "prefix"
    grammar.declarations_tokens.should_not be_empty
    grammar.rules_tokens.should_not be_empty
    grammar.epilogue_tokens.should be_empty
  end

  it "captures %define and %locations from directives fixture" do
    path = File.join(__DIR__, "fixtures", "directives.y")
    grammar_file = Lrama::Lexer::GrammarFile.new(path, File.read(path))
    lexer = Lrama::Lexer.new(grammar_file)
    parser = Lrama::GrammarParser.new(lexer)
    grammar = parser.parse

    grammar.define["api.value.type"].should eq "int"
    grammar.locations?.should be_true
  end
end
