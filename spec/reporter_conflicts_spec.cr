require "./spec_helper"

private def build_states(text : String)
  grammar_file = Lrama::Lexer::GrammarFile.new("reporter_conflicts.y", text)
  grammar = Lrama::GrammarParser.new(Lrama::Lexer.new(grammar_file)).parse
  grammar.prepare
  grammar.validate!
  states = Lrama::States.new(grammar, Lrama::Tracer.new)
  states.compute
  states
end

describe Lrama::Reporter do
  it "prints conflict summaries for shift/reduce conflicts" do
    grammar_text = <<-Y
      %token ID
      %%
      start: start start
           | ID
           ;
      %%
      Y

    states = build_states(grammar_text)
    output = IO::Memory.new
    Lrama::Reporter.new.report(output, states)
    output.to_s.includes?("shift/reduce").should be_true
    output.to_s.includes?("State").should be_true
  end
end
