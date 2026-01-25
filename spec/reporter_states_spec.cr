require "./spec_helper"

private def build_states(text : String)
  grammar_file = Lrama::Lexer::GrammarFile.new("reporter_states.y", text)
  grammar = Lrama::GrammarParser.new(Lrama::Lexer.new(grammar_file)).parse
  grammar.prepare
  grammar.validate!
  states = Lrama::States.new(grammar, Lrama::Tracer.new)
  states.compute
  states
end

describe Lrama::Reporter::States do
  it "prints lookaheads when enabled" do
    grammar_text = <<-Y
      %token ID PLUS
      %%
      start: expr ;
      expr: expr PLUS expr
          | ID
          ;
      %%
      Y

    states = build_states(grammar_text)
    output = IO::Memory.new
    Lrama::Reporter::States.new(lookaheads: true).report(output, states)
    output.to_s.includes?("  [").should be_true
  end

  it "prints verbose sections when enabled" do
    grammar_text = <<-Y
      %token ID PLUS
      %%
      start: expr ;
      expr: expr PLUS expr
          | ID
          ;
      %%
      Y

    states = build_states(grammar_text)
    output = IO::Memory.new
    Lrama::Reporter::States.new(verbose: true).report(output, states)
    output.to_s.includes?("[Direct Read sets]").should be_true
    output.to_s.includes?("[Look-Ahead Sets]").should be_true
  end

  it "prints conflict resolutions when solved is enabled" do
    grammar_text = <<-Y
      %token ID PLUS STAR
      %left PLUS
      %left STAR
      %%
      start: expr ;
      expr: expr PLUS expr
          | expr STAR expr
          | ID
          ;
      %%
      Y

    states = build_states(grammar_text)
    output = IO::Memory.new
    Lrama::Reporter::States.new(solved: true).report(output, states)
    output.to_s.includes?("Conflict between rule").should be_true
    output.to_s.includes?("resolved as").should be_true
  end

  it "prints closure items when itemsets is enabled" do
    grammar_text = <<-Y
      %token ID
      %%
      start: expr ;
      expr: ID ;
      %%
      Y

    states = build_states(grammar_text)
    without_itemsets = IO::Memory.new
    Lrama::Reporter::States.new.report(without_itemsets, states)
    with_itemsets = IO::Memory.new
    Lrama::Reporter::States.new(itemsets: true).report(with_itemsets, states)
    without_itemsets.to_s.includes?("expr: • ID").should be_false
    with_itemsets.to_s.includes?("expr: • ID").should be_true
  end

  it "prints IELR split states when enabled" do
    path = File.expand_path(File.join(__DIR__, "..", "lrama", "spec", "fixtures", "integration", "ielr.y"))
    grammar_file = Lrama::Lexer::GrammarFile.new(path, File.read(path))
    grammar = Lrama::GrammarParser.new(Lrama::Lexer.new(grammar_file)).parse
    grammar.prepare
    grammar.validate!

    states = Lrama::States.new(grammar, Lrama::Tracer.new)
    states.compute
    states.compute_ielr

    output = IO::Memory.new
    Lrama::Reporter::States.new.report(output, states, ielr: true)
    output.to_s.includes?("Split States").should be_true
  end
end
