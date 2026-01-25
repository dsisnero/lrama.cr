require "./spec_helper"

private def build_states(text : String)
  grammar_file = Lrama::Lexer::GrammarFile.new("reporter_precedences.y", text)
  grammar = Lrama::GrammarParser.new(Lrama::Lexer.new(grammar_file)).parse
  grammar.prepare
  grammar.validate!
  states = Lrama::States.new(grammar, Lrama::Tracer.new)
  states.compute
  states
end

describe Lrama::Reporter::Precedences do
  it "prints precedence resolutions when used" do
    grammar_text = <<-Y
      %token ID PLUS STAR
      %left PLUS
      %left STAR
      %%
      expr: expr PLUS expr
          | expr STAR expr
          | ID
          ;
      %%
      Y

    states = build_states(grammar_text)
    output = IO::Memory.new
    Lrama::Reporter::Precedences.new.report(output, states)
    output.to_s.includes?("Precedences").should be_true
    output.to_s.includes?("resolve conflict").should be_true
  end
end
