require "./spec_helper"

private def build_states(text : String)
  grammar_file = Lrama::Lexer::GrammarFile.new("lalr_states.y", text)
  grammar = Lrama::GrammarParser.new(Lrama::Lexer.new(grammar_file)).parse
  grammar.prepare
  grammar.validate!
  states = Lrama::States.new(grammar, Lrama::Tracer.new)
  states.compute
  states
end

describe Lrama::States do
  it "reports shift/reduce conflicts for ambiguous grammar" do
    grammar_text = <<-Y
      %token ID
      %%
      start: start start
           | ID
           ;
      %%
      Y

    states = build_states(grammar_text)
    states.sr_conflicts_count.should be > 0
  end

  it "reports reduce/reduce conflicts for empty alternatives" do
    grammar_text = <<-Y
      %%
      start: a
           | b
           ;
      a:
           ;
      b:
           ;
      %%
      Y

    states = build_states(grammar_text)
    states.rr_conflicts_count.should be > 0
  end
end
