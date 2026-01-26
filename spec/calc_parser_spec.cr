require "./spec_helper"

require "../sample/calc_parser"

class CalcStringLexer
  include Lrama::Runtime::Lexer

  def initialize(@input : String)
    @index = 0
    @bytesize = @input.bytesize
  end

  # ameba:disable Metrics/CyclomaticComplexity
  def next_token : Lrama::Runtime::Token
    while @index < @bytesize
      byte = @input.byte_at(@index)
      case byte
      when 32, 9 # space, tab
        @index += 1
        next
      when 10 # \n
        @index += 1
        return Lrama::Runtime::Token.new(CalcParser::YYSYMBOL_LF)
      when 43 # +
        @index += 1
        return Lrama::Runtime::Token.new(CalcParser::YYSYMBOL_PLUS)
      when 45 # -
        @index += 1
        return Lrama::Runtime::Token.new(CalcParser::YYSYMBOL_MINUS)
      when 42 # *
        @index += 1
        return Lrama::Runtime::Token.new(CalcParser::YYSYMBOL_STAR)
      when 47 # /
        @index += 1
        return Lrama::Runtime::Token.new(CalcParser::YYSYMBOL_SLASH)
      when 40 # (
        @index += 1
        return Lrama::Runtime::Token.new(CalcParser::YYSYMBOL_LPAREN)
      when 41 # )
        @index += 1
        return Lrama::Runtime::Token.new(CalcParser::YYSYMBOL_RPAREN)
      end

      if byte >= 48 && byte <= 57
        value = 0
        while @index < @bytesize
          digit = @input.byte_at(@index)
          break unless digit >= 48 && digit <= 57
          value = value * 10 + (digit - 48)
          @index += 1
        end
        return Lrama::Runtime::Token.new(CalcParser::YYSYMBOL_NUM, value)
      end

      raise "Unexpected byte: #{byte}"
    end

    Lrama::Runtime::Token.new(CalcParser::YYEOF)
  end
  # ameba:enable Metrics/CyclomaticComplexity
end

private def parse_calc(input : String) : Array(Int32)
  parser = CalcParser.new
  parser.parse(CalcStringLexer.new(input))
  parser.results
end

describe "calc parser" do
  it "parses single numbers" do
    parse_calc("1\n").should eq([1])
  end

  it "respects operator precedence" do
    parse_calc("1+2*3\n").should eq([7])
  end

  it "handles parentheses" do
    parse_calc("(1+2)*3\n").should eq([9])
  end
end
