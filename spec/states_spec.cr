require "./spec_helper"

describe Lrama::States do
  it "builds LR(0) states for a small grammar" do
    grammar_text = <<-Y
      %token NUMBER
      %%
      expr: expr '+' term
          | term
          ;
      term: NUMBER ;
      %%
      Y

    file = Lrama::Lexer::GrammarFile.new("specs/basic.y", grammar_text)
    lexer = Lrama::Lexer.new(file)
    grammar = Lrama::GrammarParser.new(lexer).parse
    grammar.prepare
    grammar.validate!

    states = Lrama::States.new(grammar, Lrama::Tracer.new)
    states.compute

    states.states_count.should be > 0
    states.states.first.kernels.size.should be > 0
    states.states.flat_map(&.items).size.should be > 0
  end
end
