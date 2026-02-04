/*
 * Crystal port of lrama/sample/calc.y
 *
 * Usage:
 *   crystal run src/lrama/main.cr -- samples/calc.y -o samples/calc_parser.cr
 *   crystal build samples/calc_parser.cr -o temp/calc_parser
 *   printf "1\n1+2*3\n(1+2)*3\n" | temp/calc_parser
 */

%{
require "../src/lrama/runtime"
%}

%token NUM LF
%token PLUS MINUS STAR SLASH LPAREN RPAREN

%left PLUS MINUS
%left STAR SLASH

%locations

%lexer {
  skip /[ \t]+/
  token LF /\n/
  token NUM /[0-9]+/ int
  token PLUS "+"
  token MINUS "-"
  token STAR "*"
  token SLASH "/"
  token LPAREN "("
  token RPAREN ")"
}

%%

list : /* empty */
     | list LF
     | list expr LF { puts "=> #{to_i($2)}" }
     ;

expr : NUM
     | expr op expr { $$ = apply($2, $1, $3) }
     | LPAREN expr RPAREN  { $$ = $2 }
     ;

op : PLUS  { $$ = :+ }
   | MINUS { $$ = :- }
   | STAR  { $$ = :* }
   | SLASH { $$ = :/ }
   ;

%%

def to_i(value)
  case value
  when Int32
    value
  when Int64
    value.to_i
  when String
    value.to_i
  when Nil
    0
  else
    0
  end
end

def apply(op, left, right)
  l = to_i(left)
  r = to_i(right)
  case op
  when :+
    l + r
  when :-
    l - r
  when :*
    l * r
  when :/
    l / r
  else
    0
  end
end

if PROGRAM_NAME.ends_with?("calc_parser")
  input = STDIN.gets_to_end
  puts "Enter the formula:"
  parser = CalcParser.new
  lexer = CalcParserLexer.new(input)
  parser.parse(lexer)
end
