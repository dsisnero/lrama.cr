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
%lexer {
  skip /[ \t]+/
  token NUM /[0-9]+/ int
  token LF /\n/
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
class CalcParser
  def results
    @results ||= [] of Int32
  end
end

if PROGRAM_NAME.ends_with?("calc_parser")
  if STDIN.tty?
    while (line = STDIN.gets)
      input = line.ends_with?('\n') ? line : "#{line}\n"
      parser = CalcParser.run(IO::Memory.new(input))
      parser.results.each { |value| puts "=> #{value}" }
    end
  else
    parser = CalcParser.run
    parser.results.each { |value| puts "=> #{value}" }
  end
end
