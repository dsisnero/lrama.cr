require "./spec_helper"

private def build_states(text : String)
  grammar_file = Lrama::Lexer::GrammarFile.new("reporter_terms.y", text)
  grammar = Lrama::GrammarParser.new(Lrama::Lexer.new(grammar_file)).parse
  grammar.prepare
  grammar.validate!
  states = Lrama::States.new(grammar, Lrama::Tracer.new)
  states.compute
  states
end

describe Lrama::Reporter::Terms do
  it "prints term and unused term counts" do
    grammar_text = <<-Y
      %token ID UNUSED
      %%
      start: ID ;
      %%
      Y

    states = build_states(grammar_text)
    output = IO::Memory.new
    Lrama::Reporter::Terms.new(terms: true).report(output, states)
    output.to_s.includes?("Terms").should be_true
    output.to_s.includes?("Unused Terms").should be_true
  end
end
