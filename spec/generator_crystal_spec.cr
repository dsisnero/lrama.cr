require "./spec_helper"

describe Lrama::Generator::Crystal do
  it "renders a Crystal parser class with tables" do
    text = [
      "%token NUM",
      "%%",
      "start: NUM ;",
      "%%",
      "",
    ].join("\n")
    grammar_file = Lrama::Lexer::GrammarFile.new("gen_parser.y", text)
    grammar = Lrama::GrammarParser.new(Lrama::Lexer.new(grammar_file)).parse
    grammar.prepare

    tables = Lrama::Generator::Crystal::Tables.new(
      yypact: [0, -1],
      yypgoto: [0],
      yydefact: [0, 0],
      yydefgoto: [0],
      yytable: [0],
      yycheck: [0],
      yyr1: [0, 1],
      yyr2: [0, 1],
      yylast: 0,
      yypact_ninf: -1,
      yytable_ninf: -1,
      yyfinal: 0,
      error_symbol: 1,
      eof_symbol: 0,
      yyntokens: grammar.terms.size
    )

    generator = Lrama::Generator::Crystal.new(grammar, tables, "MyParser")
    output = IO::Memory.new
    generator.render(output)

    rendered = output.to_s
    rendered.includes?("class MyParser < Lrama::Runtime::Parser").should be_true
    rendered.includes?("YYPACT = [0, -1]").should be_true
    rendered.includes?("YYFINAL = 0").should be_true
  end

  it "translates rule actions into Crystal expressions" do
    text = [
      "%token NUM",
      "%%",
      "start: NUM { $$ = $1 } ;",
      "%%",
      "",
    ].join("\n")
    grammar_file = Lrama::Lexer::GrammarFile.new("gen_parser.y", text)
    grammar = Lrama::GrammarParser.new(Lrama::Lexer.new(grammar_file)).parse
    grammar.prepare

    tables = Lrama::Generator::Crystal::Tables.new(
      yypact: [0, -1],
      yypgoto: [0],
      yydefact: [0, 0],
      yydefgoto: [0],
      yytable: [0],
      yycheck: [0],
      yyr1: [0, 1],
      yyr2: [0, 1],
      yylast: 0,
      yypact_ninf: -1,
      yytable_ninf: -1,
      yyfinal: 0,
      error_symbol: 1,
      eof_symbol: 0,
      yyntokens: grammar.terms.size
    )

    generator = Lrama::Generator::Crystal.new(grammar, tables, "MyParser")
    output = IO::Memory.new
    generator.render(output)

    rendered = output.to_s
    rendered.includes?("result = values[0]").should be_true
  end
end
