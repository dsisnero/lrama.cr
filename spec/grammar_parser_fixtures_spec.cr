require "./spec_helper"

private def parse_fixture(path : String)
  grammar_file = Lrama::Lexer::GrammarFile.new(path, File.read(path))
  lexer = Lrama::Lexer.new(grammar_file)
  parser = Lrama::GrammarParser.new(lexer)
  parser.parse
end

describe Lrama::GrammarParser do
  it "parses parameterized rule fixture with named references" do
    path = File.join(__DIR__, "fixtures", "parameterized", "user_defined", "with_action_and_named_references.y")
    grammar = parse_fixture(path)

    grammar.parameterized_rules.size.should eq 1
    rule = grammar.parameterized_rules.first
    rule.name.should eq "sum"
    rule.parameters.map(&.s_value).should eq ["X", "Y"]
    rule.tag.should_not be_nil
    rule.tag.try(&.s_value).should eq "<i>"

    rhs = rule.rhs.first
    rhs.symbols.size.should eq 3
    rhs.symbols.first.alias_name.should eq "summand"
    rhs.symbols.last.alias_name.should eq "addend"
  end

  it "parses parameterized rule tags in rules section" do
    path = File.join(__DIR__, "fixtures", "parameterized", "user_defined", "with_tag.y")
    grammar = parse_fixture(path)

    rules = grammar.rule_builders.select { |builder| builder.lhs.try(&.s_value) == "program" }
    rules.size.should eq 2
    tagged = rules.find do |builder|
      builder.rhs.first?.is_a?(Lrama::Lexer::Token::InstantiateRule) &&
        builder.rhs.first.as(Lrama::Lexer::Token::InstantiateRule).lhs_tag.try(&.s_value) == "<s>"
    end
    tagged.should_not be_nil
  end

  it "captures prologue and epilogue in integration fixture" do
    path = File.join(__DIR__, "fixtures", "integration", "prologue_epilogue_optional.y")
    grammar = parse_fixture(path)

    grammar.prologue.should_not be_nil
    grammar.prologue_first_lineno.should eq 1
    grammar.epilogue.should_not be_nil
  end
end
