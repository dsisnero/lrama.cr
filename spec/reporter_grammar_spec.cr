require "./spec_helper"

private def build_states(text : String)
  grammar_file = Lrama::Lexer::GrammarFile.new("reporter_grammar.y", text)
  grammar = Lrama::GrammarParser.new(Lrama::Lexer.new(grammar_file)).parse
  grammar.prepare
  grammar.validate!
  states = Lrama::States.new(grammar, Lrama::Tracer.new)
  states.compute
  states
end

describe Lrama::Reporter do
  it "prints grammar listing when enabled" do
    grammar_text = <<-Y
      %token ID
      %%
      start: ID ;
      %%
      Y

    states = build_states(grammar_text)
    output = IO::Memory.new
    Lrama::Reporter.new(grammar: true).report(output, states)
    output.to_s.includes?("Grammar").should be_true
    output.to_s.includes?("start").should be_true
  end
end
