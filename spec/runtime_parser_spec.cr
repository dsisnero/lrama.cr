require "./spec_helper"

private class RuntimeLexer
  include Lrama::Runtime::Lexer

  def initialize(@tokens : Array(Lrama::Runtime::Token))
    @index = 0
  end

  def next_token : Lrama::Runtime::Token
    if token = @tokens[@index]?
      @index += 1
      token
    else
      Lrama::Runtime::Token.new(RuntimeParser::SYM_EOF)
    end
  end
end

private class RuntimeParser < Lrama::Runtime::Parser
  YYNTOKENS    =  9
  YYLAST       = 13
  YYTABLE_NINF = -1
  YYTABLE      = [5, 6, 7, 9, 8, 9, 11, 12, 8, 9, 1, 10, 0, 2]
  YYCHECK      = [2, 0, 3, 6, 5, 6, 8, 9, 5, 6, 4, 8, -1, 7]

  YYPACT_NINF = -4
  YYPACT      = [6, -4, 6, 1, -1, 3, -4, -4, 6, 6, -4, -3, -4]
  YYPGOTO     = [-4, -4, -2]

  YYDEFACT  = [2, 4, 0, 0, 0, 0, 1, 3, 0, 0, 7, 5, 6]
  YYDEFGOTO = [0, 3, 4]

  YYR1 = [0, 9, 10, 10, 11, 11, 11, 11]
  YYR2 = [0, 2, 0, 2, 1, 3, 3, 3]

  YYFINAL = 6

  SYM_EMPTY   = -2
  SYM_EOF     =  0
  SYM_ERROR   =  1
  SYM_UNDEF   =  2
  SYM_LF      =  3
  SYM_NUM     =  4
  SYM_PLUS    =  5
  SYM_ASTER   =  6
  SYM_LPAREN  =  7
  SYM_RPAREN  =  8
  SYM_ACCEPT  =  9
  SYM_PROGRAM = 10
  SYM_EXPR    = 11

  def yypact : Array(Int32)
    YYPACT
  end

  def yypgoto : Array(Int32)
    YYPGOTO
  end

  def yydefact : Array(Int32)
    YYDEFACT
  end

  def yydefgoto : Array(Int32)
    YYDEFGOTO
  end

  def yytable : Array(Int32)
    YYTABLE
  end

  def yycheck : Array(Int32)
    YYCHECK
  end

  def yyr1 : Array(Int32)
    YYR1
  end

  def yyr2 : Array(Int32)
    YYR2
  end

  def yylast : Int32
    YYLAST
  end

  def yyntokens : Int32
    YYNTOKENS
  end

  def yypact_ninf : Int32
    YYPACT_NINF
  end

  def yytable_ninf : Int32
    YYTABLE_NINF
  end

  def yyfinal : Int32
    YYFINAL
  end

  def error_symbol : Int32
    SYM_ERROR
  end

  def reduce(_rule : Int32, _values : Array(Object?), _locations : Array(Lrama::Runtime::Location?))
    nil
  end
end

describe Lrama::Runtime::Parser do
  it "parses a basic token stream" do
    tokens = [
      RuntimeParser::SYM_NUM,
      RuntimeParser::SYM_PLUS,
      RuntimeParser::SYM_NUM,
      RuntimeParser::SYM_PLUS,
      RuntimeParser::SYM_NUM,
      RuntimeParser::SYM_LF,
    ].map { |sym| Lrama::Runtime::Token.new(sym) }

    lexer = RuntimeLexer.new(tokens)
    parser = RuntimeParser.new

    parser.parse(lexer).should eq 0
  end
end
