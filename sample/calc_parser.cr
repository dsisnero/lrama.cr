

require "../src/lrama/runtime"



class CalcParser < Lrama::Runtime::Parser

  YYSYMBOL_YYEOF = 0

  YYSYMBOL_YYerror = 1

  YYSYMBOL_YYUNDEF = 2

  YYSYMBOL_LF = 3

  YYSYMBOL_NUM = 4

  YYSYMBOL_PLUS = 5

  YYSYMBOL_MINUS = 6

  YYSYMBOL_STAR = 7

  YYSYMBOL_SLASH = 8

  YYSYMBOL_LPAREN = 9

  YYSYMBOL_RPAREN = 10

  YYSYMBOL_YYACCEPT = 11

  YYSYMBOL_list = 12

  YYSYMBOL_expr = 13

  YYEMPTY = -2
  YYERROR = 1
  YYEOF = 0
  YYNTOKENS = 11

  YYPACT = [
    -5, 0, -5, -5, -5, 16, 7, 11, -5, 16, 16, 16,
    16, -5, 15, 15, -5, -5
  ]
  YYPGOTO = [-5, -5, -4]
  YYDEFACT = [
    2, 0, 1, 3, 5, 0, 0, 0, 4, 0, 0, 0,
    0, 10, 6, 7, 8, 9
  ]
  YYDEFGOTO = [0, 1, 6]
  YYTABLE = [
    2, 7, 0, 3, 4, 14, 15, 16, 17, 5, 8, 0,
    9, 10, 11, 12, 9, 10, 11, 12, 4, 13, 11, 12,
    0, 5
  ]
  YYCHECK = [
    0, 5, -1, 3, 4, 9, 10, 11, 12, 9, 3, -1,
    5, 6, 7, 8, 5, 6, 7, 8, 4, 10, 7, 8,
    -1, 9
  ]
  YYR1 = [0, 11, 12, 12, 12, 13, 13, 13, 13, 13, 13]
  YYR2 = [0, 2, 0, 2, 3, 1, 3, 3, 3, 3, 3]
  YYLAST = 25
  YYPACT_NINF = -5
  YYTABLE_NINF = -1
  YYFINAL = 2

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
    YYERROR
  end

  def eof_symbol : Int32
    YYEOF
  end

  def reduce(rule : Int32, values : Array(Lrama::Runtime::Value), locations : Array(Lrama::Runtime::Location?)) : Lrama::Runtime::Value
    case rule
    when 0
      nil

    when 1
      # $accept -> list YYEOF
      values.last?


    when 2
      # list -> %empty
      nil


    when 3
      # list -> list LF
      values.last?


    when 4
      # list -> list expr LF
      result = values.last?
       results << (values[1]).as(Int32);
      result


    when 5
      # expr -> NUM
      values.last?


    when 6
      # expr -> expr PLUS expr
      result = values.last?
       result = (values[0]).as(Int32) + (values[2]).as(Int32);
      result


    when 7
      # expr -> expr MINUS expr
      result = values.last?
       result = (values[0]).as(Int32) - (values[2]).as(Int32);
      result


    when 8
      # expr -> expr STAR expr
      result = values.last?
       result = (values[0]).as(Int32) * (values[2]).as(Int32);
      result


    when 9
      # expr -> expr SLASH expr
      result = values.last?
       result = (values[0]).as(Int32) / (values[2]).as(Int32);
      result


    when 10
      # expr -> LPAREN expr RPAREN
      result = values.last?
       result = (values[1]).as(Int32);
      result


    else
      nil
    end
  end
end




class CalcLexer
  include Lrama::Runtime::Lexer

  def initialize(@io : IO)
    @buffered = nil.as(UInt8?)
  end

  # ameba:disable Metrics/CyclomaticComplexity
  def next_token : Lrama::Runtime::Token
    loop do
      byte = @buffered || @io.read_byte
      @buffered = nil
      return Lrama::Runtime::Token.new(CalcParser::YYEOF) unless byte

      case byte
      when 32, 9 # space, tab
        next
      when 10 # \n
        return Lrama::Runtime::Token.new(CalcParser::YYSYMBOL_LF)
      when 43 # +
        return Lrama::Runtime::Token.new(CalcParser::YYSYMBOL_PLUS)
      when 45 # -
        return Lrama::Runtime::Token.new(CalcParser::YYSYMBOL_MINUS)
      when 42 # *
        return Lrama::Runtime::Token.new(CalcParser::YYSYMBOL_STAR)
      when 47 # /
        return Lrama::Runtime::Token.new(CalcParser::YYSYMBOL_SLASH)
      when 40 # (
        return Lrama::Runtime::Token.new(CalcParser::YYSYMBOL_LPAREN)
      when 41 # )
        return Lrama::Runtime::Token.new(CalcParser::YYSYMBOL_RPAREN)
      end

      if byte >= 48 && byte <= 57
        value = 0
        while byte >= 48 && byte <= 57
          value = value * 10 + (byte - 48)
          next_byte = @io.read_byte
          break unless next_byte
          byte = next_byte
        end
        if byte < 48 || byte > 57
          @buffered = byte
        end
        return Lrama::Runtime::Token.new(CalcParser::YYSYMBOL_NUM, value)
      end

      raise "Unexpected byte: #{byte}"
    end
  end
  # ameba:enable Metrics/CyclomaticComplexity
end

class CalcParser
  def results
    @results ||= [] of Int32
  end
end

if PROGRAM_NAME.ends_with?("calc_parser")
  parser = CalcParser.new
  parser.parse(CalcLexer.new(STDIN))
  parser.results.each { |value| puts "=> #{value}" }
end


