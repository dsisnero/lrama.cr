/*
 * Crystal port of lrama/sample/parse.y
 *
 * Usage:
 *   crystal run src/lrama/main.cr -- samples/parse.y -o samples/parse_parser.cr
 *   crystal build samples/parse_parser.cr -o temp/parse_parser
 *   printf "2+3*4" | temp/parse_parser
 */

%{
require "../src/lrama/runtime"
%}

%expect 0

%token NUMBER PLUS STAR

%left PLUS
%left STAR

%lexer {
  skip /[ \t\r\n]+/
  token NUMBER /[0-9]+/ int
  token PLUS "+"
  token STAR "*"
}

%%

program : expr
        ;

expr : term PLUS expr
     | term
     ;

term : factor STAR term
     | factor
     ;

factor : NUMBER
       ;

%%

if PROGRAM_NAME.ends_with?("parse_parser")
  input = STDIN.gets_to_end
  parser = ParseParser.new
  lexer = ParseParserLexer.new(input)
  result = parser.parse(lexer)
  STDERR.puts "parse error" unless result == 0
end
