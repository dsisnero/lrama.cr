/*
 * Crystal port of lrama/sample/json.y
 *
 * Usage:
 *   crystal run src/lrama/main.cr -- samples/json.y -o samples/json_parser.cr
 *   crystal build samples/json_parser.cr -o temp/json_parser
 *   printf '{"foo": 42, "bar": [1, 2, 3], "baz": {"qux": true}}' | temp/json_parser
 */

%{
require "../src/lrama/runtime"
%}

%token STRING NUMBER TRUE FALSE NULL_T IDENT
%token LBRACE RBRACE LBRACKET RBRACKET COLON COMMA

%locations

%lexer {
  keywords case_insensitive TRUE FALSE NULL_T
  skip /[ \t\r\n]+/
  token STRING /\"[^\"]*\"/ string
  token NUMBER /-?[0-9]+(?:\.[0-9]+)?/ float
  token IDENT /[A-Za-z_][A-Za-z0-9_]*/ string keyword
  token LBRACE "{"
  token RBRACE "}"
  token LBRACKET "["
  token RBRACKET "]"
  token COLON ":"
  token COMMA ","
}

%%

json: object
    | array
    ;

object: LBRACE members_opt RBRACE
      ;

members_opt: /* empty */
           | members
           ;

members: pair
       | members COMMA pair
       ;

pair: STRING COLON value
    ;

array: LBRACKET elements_opt RBRACKET
     ;

elements_opt: /* empty */
            | elements
            ;

elements: value
        | elements COMMA value
        ;

value: STRING
     | NUMBER
     | object
     | array
     | TRUE
     | FALSE
     | NULL_T
     | IDENT { raise "Unexpected literal: #{s($1)}" }
     ;

%%

def s(value : Lrama::Runtime::Value) : String
  value.as(String)
end

if PROGRAM_NAME.ends_with?("json_parser")
  input = STDIN.gets_to_end
  parser = JsonParser.new
  lexer = JsonParserLexer.new(input)
  begin
    result = parser.parse(lexer)
    if result == 0
      puts "JSON parsed successfully!"
    else
      STDERR.puts "Error: parse error"
    end
  rescue ex
    STDERR.puts ex.message
    exit 1
  end
end
