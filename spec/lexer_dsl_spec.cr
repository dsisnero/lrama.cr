require "./spec_helper"

describe Lrama::LexerSpec::RegexParser do
  it "parses alternation into multiple sequences" do
    ast = Lrama::LexerSpec::RegexParser.new("ab|cd", 1).parse
    ast.should be_a(Lrama::LexerSpec::Alternation)
    options = ast.as(Lrama::LexerSpec::Alternation).options
    options.size.should eq(2)
    options.all?(Lrama::LexerSpec::Sequence).should be_true
  end

  it "parses negated char classes" do
    ast = Lrama::LexerSpec::RegexParser.new("[^']", 1).parse
    seq = ast.as(Lrama::LexerSpec::Sequence)
    char_class = seq.parts.first.as(Lrama::LexerSpec::CharClass)
    set = char_class.set
    set.include?('\''.ord.to_u8).should be_false
    set.include?('a'.ord.to_u8).should be_true
  end

  it "parses dot as any char" do
    ast = Lrama::LexerSpec::RegexParser.new(".", 1).parse
    seq = ast.as(Lrama::LexerSpec::Sequence)
    seq.parts.first.should be_a(Lrama::LexerSpec::AnyChar)
  end

  it "parses bounded repetition" do
    ast = Lrama::LexerSpec::RegexParser.new("a{2,3}", 1).parse
    seq = ast.as(Lrama::LexerSpec::Sequence)
    repeat = seq.parts.first.as(Lrama::LexerSpec::Repeat)
    repeat.min.should eq(2)
    repeat.max.should eq(3)
  end

  it "parses open-ended repetition" do
    ast = Lrama::LexerSpec::RegexParser.new("a{2,}", 1).parse
    seq = ast.as(Lrama::LexerSpec::Sequence)
    repeat = seq.parts.first.as(Lrama::LexerSpec::Repeat)
    repeat.min.should eq(2)
    repeat.max.should be_nil
  end
end

describe Lrama::LexerSpec::Parser do
  it "parses keyword directives and keyword rules" do
    source = <<-LEXER
      keywords case_insensitive SELECT FROM
      token ID /[A-Za-z]+/ string keyword
      LEXER
    spec = Lrama::LexerSpec::Parser.new(source, 1).parse
    spec.keywords_case_insensitive?.should be_true
    spec.keywords.should eq(["SELECT", "FROM"])
    spec.rules.size.should eq(1)
    spec.rules.first.keyword?.should be_true
  end

  it "requires keywords directive for keyword rules" do
    source = "token ID /[A-Za-z]+/ string keyword\n"
    expect_raises(Lrama::LexerSpec::ParseError) do
      Lrama::LexerSpec::Parser.new(source, 1).parse
    end
  end

  it "parses lexer states and rule state filters" do
    source = <<-LEXER
      state STRING
      token ID /[A-Za-z]+/ string in=INITIAL
      token STR /[^']*/ string in=STRING
      LEXER
    spec = Lrama::LexerSpec::Parser.new(source, 1).parse
    spec.states.should eq(["INITIAL", "STRING"])
    spec.rules[0].states.should eq(["INITIAL"])
    spec.rules[1].states.should eq(["STRING"])
  end
end
