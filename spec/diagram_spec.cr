require "./spec_helper"

private def build_grammar(text : String)
  grammar_file = Lrama::Lexer::GrammarFile.new("diagram.y", text)
  grammar = Lrama::GrammarParser.new(Lrama::Lexer.new(grammar_file)).parse
  grammar.prepare
  grammar
end

describe Lrama::Diagram do
  it "renders HTML with rule headers" do
    grammar = build_grammar([
      "%token ID",
      "%%",
      "start: ID ;",
      "%%",
      "",
    ].join("\n"))

    output = IO::Memory.new
    Lrama::Diagram.render(io: output, grammar: grammar)

    html = output.to_s
    html.includes?("<h2").should be_true
    html.includes?("start").should be_true
    html.includes?("ID").should be_true
  end
end
