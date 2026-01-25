require "./spec_helper"

private def build_states(text : String)
  grammar_file = Lrama::Lexer::GrammarFile.new("counterexamples.y", text)
  grammar = Lrama::GrammarParser.new(Lrama::Lexer.new(grammar_file)).parse
  grammar.prepare
  grammar.validate!
  states = Lrama::States.new(grammar, Lrama::Tracer.new)
  states.compute
  states
end

describe Lrama::Counterexamples do
  it "computes counterexamples for conflicted states" do
    grammar_text = <<-Y
      %token ID
      %%
      start: start start
           | ID
           ;
      %%
      Y

    states = build_states(grammar_text)
    conflict_state = states.states.find(&.has_conflicts?)
    conflict_state.should_not be_nil

    counterexamples = Lrama::Counterexamples.new(states)
    examples = counterexamples.compute(conflict_state || raise "Conflict state missing")
    examples.should be_a(Array(Lrama::Counterexamples::Example))
  end
end
