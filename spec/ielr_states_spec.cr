require "./spec_helper"

describe Lrama::States do
  it "splits IELR states and marks IELR precedence usage" do
    path = File.expand_path(File.join(__DIR__, "..", "lrama", "spec", "fixtures", "integration", "ielr.y"))
    grammar_file = Lrama::Lexer::GrammarFile.new(path, File.read(path))
    lexer = Lrama::Lexer.new(grammar_file)
    grammar = Lrama::GrammarParser.new(lexer).parse
    grammar.prepare
    grammar.validate!

    states = Lrama::States.new(grammar, Lrama::Tracer.new)
    states.compute
    initial_count = states.states_count
    states.compute_ielr

    states.states_count.should be > initial_count
    grammar.precedences.any?(&.used_by_ielr?).should be_true
  end
end
