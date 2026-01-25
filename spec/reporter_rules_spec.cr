require "./spec_helper"

private def build_states(text : String)
  grammar_file = Lrama::Lexer::GrammarFile.new("reporter_rules.y", text)
  grammar = Lrama::GrammarParser.new(Lrama::Lexer.new(grammar_file)).parse
  grammar.prepare
  grammar.validate!
  states = Lrama::States.new(grammar, Lrama::Tracer.new)
  states.compute
  states
end

describe Lrama::Reporter::Rules do
  it "prints rule usage frequency" do
    grammar_text = <<-Y
      %token ID
      %%
      start: ID ;
      %%
      Y

    states = build_states(grammar_text)
    output = IO::Memory.new
    Lrama::Reporter::Rules.new(rules: true).report(output, states)
    output.to_s.includes?("Rule Usage Frequency").should be_true
    output.to_s.includes?("start").should be_true
  end
end
