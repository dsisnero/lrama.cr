/*
 * Crystal-friendly calculator grammar for lrama.
 *
 * Example usage:
 *   crystal run src/lrama/main.cr -- sample/calc.y -o sample/calc_parser.cr
 *   crystal build sample/calc_parser.cr -o calc_parser
 *   printf "1+2*3\n" | ./calc_parser
 */

%{
require "../src/lrama/runtime"
%}

%token LF
%token NUM
%token PLUS MINUS STAR SLASH LPAREN RPAREN
%left PLUS MINUS
%left STAR SLASH

%%

list : /* empty */
     | list LF
     | list expr LF { results << ($2).as(Int32); }
     ;
expr : NUM
     | expr PLUS expr   { $$ = ($1).as(Int32) + ($3).as(Int32); }
     | expr MINUS expr  { $$ = ($1).as(Int32) - ($3).as(Int32); }
     | expr STAR expr   { $$ = ($1).as(Int32) * ($3).as(Int32); }
     | expr SLASH expr  { $$ = ($1).as(Int32) / ($3).as(Int32); }
     | LPAREN expr RPAREN { $$ = ($2).as(Int32); }
     ;

%%

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
