require "./spec_helper"

describe Lrama::GrammarParser do
  it "collects declarations, rules, and epilogue tokens" do
    path = File.join(__DIR__, "fixtures", "common", "basic.y")
    grammar_file = Lrama::Lexer::GrammarFile.new(path, File.read(path))
    lexer = Lrama::Lexer.new(grammar_file)
    parser = Lrama::GrammarParser.new(lexer)
    grammar = parser.parse

    grammar.prologue.should eq "\n// Prologue\n"
    grammar.declarations_tokens.should_not be_empty
    grammar.rules_tokens.should_not be_empty
    grammar.epilogue_tokens.should be_empty
  end
end
