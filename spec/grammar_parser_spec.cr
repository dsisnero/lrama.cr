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
    grammar.union.should_not be_nil
    grammar.union.try(&.braces_less_code.includes?("int i;")).should be_true
    grammar.lex_param.should eq "struct lex_params *p"
    grammar.parse_param.should eq "struct parse_params *p"
    initial_action = grammar.initial_action
    initial_action.should_not be_nil
    initial_action.try(&.code.includes?("initial_action_func")).should be_true
    grammar.printers.size.should eq 2
    grammar.declarations_tokens.should_not be_empty
    grammar.rule_builders.should_not be_empty
    grammar.epilogue_tokens.should be_empty
    grammar.aux.prologue.should eq grammar.prologue
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

  it "captures after hooks and epilogue" do
    text = [
      "%after-shift after_shift_cb",
      "%before-reduce before_reduce_cb",
      "%after-reduce after_reduce_cb",
      "%after-shift-error-token after_shift_error_cb",
      "%after-pop-stack after_pop_cb",
      "%%",
      "rule: ;",
      "%%",
      "epilogue code",
      "",
    ].join("\n")
    grammar_file = Lrama::Lexer::GrammarFile.new("hooks.y", text)
    lexer = Lrama::Lexer.new(grammar_file)
    parser = Lrama::GrammarParser.new(lexer)
    grammar = parser.parse

    grammar.after_shift.should eq "after_shift_cb"
    grammar.before_reduce.should eq "before_reduce_cb"
    grammar.after_reduce.should eq "after_reduce_cb"
    grammar.after_shift_error_token.should eq "after_shift_error_cb"
    grammar.after_pop_stack.should eq "after_pop_cb"
    grammar.epilogue.should eq "\nepilogue code\n"
    grammar.epilogue_first_lineno.should eq 8
  end

  it "parses parameterized rules and rule rhs variants" do
    text = [
      "%rule expr(a, b): a b",
      "%rule %inline list: item",
      "%%",
      "expr: term+ [t] <tag> | %empty ;",
      "%%",
      "",
    ].join("\n")
    grammar_file = Lrama::Lexer::GrammarFile.new("rules.y", text)
    lexer = Lrama::Lexer.new(grammar_file)
    parser = Lrama::GrammarParser.new(lexer)
    grammar = parser.parse

    grammar.parameterized_rules.size.should eq 2
    grammar.parameterized_rules.first.name.should eq "expr"
    grammar.parameterized_rules.first.parameters.map(&.s_value).should eq ["a", "b"]
    grammar.parameterized_rules.last.inline?.should be_true

    grammar.rule_builders.size.should eq 2
    first_rule = grammar.rule_builders.first
    first_rule.lhs.should_not be_nil
    first_rule.lhs.try(&.s_value).should eq "expr"
    first_rule.rhs.size.should eq 1
    inst = first_rule.rhs.first.as(Lrama::Lexer::Token::InstantiateRule)
    inst.rule_name.should eq "nonempty_list"
    inst.args.first.s_value.should eq "term"
    inst.alias_name.should eq "t"
    inst.lhs_tag.should_not be_nil
    inst.lhs_tag.try(&.s_value).should eq "<tag>"

    grammar.rule_builders.last.rhs.first.should be_a(Lrama::Lexer::Token::Empty)
  end
end
