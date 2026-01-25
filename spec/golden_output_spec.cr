require "./spec_helper"

private def build_states(text : String)
  grammar_file = Lrama::Lexer::GrammarFile.new("golden.y", text)
  grammar = Lrama::GrammarParser.new(Lrama::Lexer.new(grammar_file)).parse
  grammar.prepare
  states = Lrama::States.new(grammar, Lrama::Tracer.new)
  states.compute
  states
end

describe "Golden output" do
  it "matches grammar report output" do
    grammar_text = <<-Y
      %token ID
      %%
      start: ID ;
      %%
      Y

    states = build_states(grammar_text)
    output = IO::Memory.new
    Lrama::Reporter::Grammar.new(grammar: true).report(output, states)

    expected_path = File.join(__DIR__, "fixtures", "golden", "grammar_basic.output")
    expected = File.read(expected_path)
    output.to_s.should eq(expected)
  end
end
