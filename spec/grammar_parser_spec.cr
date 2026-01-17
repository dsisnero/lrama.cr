require "./spec_helper"

describe Lrama::GrammarParser do
  it "collects declarations, rules, and epilogue tokens" do
    path = File.join(__DIR__, "fixtures", "common", "basic.y")
    grammar_file = Lrama::Lexer::GrammarFile.new(path, File.read(path))
    lexer = Lrama::Lexer.new(grammar_file)
    parser = Lrama::GrammarParser.new(lexer)
    grammar = parser.parse

    grammar.prologue.should eq "\n// Prologue\n"
    grammar.required?.should be_true
    grammar.expect.should eq 0
    grammar.define["api.pure"].should be_nil
    grammar.define["parse.error"].should eq "verbose"
    grammar.define["api.prefix"].should eq "prefix"
    grammar.token_declarations.size.should be > 0
    first_decl = grammar.token_declarations.first
    first_decl.id.s_value.should eq "EOI"
    first_decl.token_id.should eq 0
    first_decl.alias_name.should eq "\"EOI\""
    grammar.type_declarations.size.should be > 0
    grammar.type_declarations.first.tokens.first.s_value.should eq "class"
    grammar.precedence_declarations.size.should be > 0
    union_code = grammar.union_code
    union_code.should_not be_nil
    union_code.try(&.code.includes?("int i;")).should be_true
    grammar.lex_param.should eq "struct lex_params *p"
    grammar.parse_param.should eq "struct parse_params *p"
    initial_action = grammar.initial_action
    initial_action.should_not be_nil
    initial_action.try(&.code.includes?("initial_action_func")).should be_true
    grammar.printers.size.should eq 2
    grammar.declarations_tokens.should_not be_empty
    grammar.rules_tokens.should_not be_empty
    grammar.epilogue_tokens.should be_empty
  end

  it "captures %define and %locations from directives fixture" do
    path = File.join(__DIR__, "fixtures", "directives.y")
    grammar_file = Lrama::Lexer::GrammarFile.new(path, File.read(path))
    lexer = Lrama::Lexer.new(grammar_file)
    parser = Lrama::GrammarParser.new(lexer)
    grammar = parser.parse

    grammar.define["api.value.type"].should eq "int"
    grammar.locations?.should be_true
    grammar.start_symbol.should eq "program"
  end
end
