require "./spec_helper"

private def build_states(text : String)
  grammar_file = Lrama::Lexer::GrammarFile.new("reporter_combined.y", text)
  grammar = Lrama::GrammarParser.new(Lrama::Lexer.new(grammar_file)).parse
  grammar.prepare
  grammar.validate!
  states = Lrama::States.new(grammar, Lrama::Tracer.new)
  states.compute
  states
end

describe Lrama::Reporter do
  it "prints combined report output for conflicts" do
    grammar_text = <<-Y
      %token '+' "plus"
      %token tNUMBER
      %%
      program: expr ;
      expr: expr '+' expr
          | tNUMBER
          ;
      %%
      Y

    states = build_states(grammar_text)
    output = IO::Memory.new
    Lrama::Reporter.new({
      :grammar    => true,
      :rules      => true,
      :terms      => true,
      :states     => true,
      :itemsets   => true,
      :lookaheads => true,
    }).report(output, states)

    expected_path = File.join(__DIR__, "fixtures", "golden", "reporter_combined.output")
    expected = File.read(expected_path)
    output.to_s.should eq(expected)
  end
end
