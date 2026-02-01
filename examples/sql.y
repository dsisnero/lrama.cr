/*
 * Simple SQL SELECT grammar for the Crystal port.
 *
 * Example usage:
 *   crystal run src/lrama/main.cr -- examples/sql.y -o examples/sql_parser.cr
 *   crystal build examples/sql_parser.cr -o temp/sql_parser
 *   printf "SELECT id, name FROM users WHERE age > 18 AND active = 1;\n" | temp/sql_parser
 */

%{
require "../src/lrama/runtime"
%}

%token SELECT FROM WHERE AND OR NOT AS
%token COMMA STAR SEMICOLON LPAREN RPAREN
%token EQ NE LT GT LE GE
%token IDENT STRING NUMBER

%left OR
%left AND
%right NOT
%left EQ NE LT GT LE GE

%lexer {
  keywords case_insensitive SELECT FROM WHERE AND OR NOT AS
  skip /[ \t\r\n]+/
  token STRING /'(?:[^'\\]|\\.)*'/
  token NUMBER /[0-9]+(?:\.[0-9]+)?/ string
  token IDENT /[A-Za-z_][A-Za-z0-9_]*/ string
  token COMMA ","
  token STAR "*"
  token SEMICOLON ";"
  token LPAREN "("
  token RPAREN ")"
  token LE "<="
  token GE ">="
  token NE "!="
  token EQ "="
  token LT "<"
  token GT ">"
}

%%

input: select_stmt SEMICOLON
        {
          @query = ($1).as(String)
        }
     ;

select_stmt: SELECT select_list FROM table_ref where_clause
              {
                $$ = "SELECT #{($2).as(String)} FROM #{($4).as(String)}#{($5).as(String)}"
              }
           ;

select_list: STAR
              {
                $$ = "*"
              }
           | column_list
              {
                $$ = ($1).as(String)
              }
           ;

column_list: column_ref
              {
                $$ = ($1).as(String)
              }
           | column_list COMMA column_ref
              {
                $$ = "#{($1).as(String)}, #{($3).as(String)}"
              }
           ;

column_ref: IDENT
             {
               $$ = ($1).as(String)
             }
          | IDENT AS IDENT
             {
               $$ = "#{($1).as(String)} AS #{($3).as(String)}"
             }
          ;

table_ref: IDENT
            {
              $$ = ($1).as(String)
            }
         | IDENT AS IDENT
            {
              $$ = "#{($1).as(String)} AS #{($3).as(String)}"
            }
         ;

where_clause: /* empty */
               {
                 $$ = ""
               }
            | WHERE condition
               {
                 $$ = " WHERE #{($2).as(String)}"
               }
            ;

condition: condition AND condition
            {
              $$ = "(#{($1).as(String)} AND #{($3).as(String)})"
            }
         | condition OR condition
            {
              $$ = "(#{($1).as(String)} OR #{($3).as(String)})"
            }
         | NOT condition
            {
              $$ = "(NOT #{($2).as(String)})"
            }
         | LPAREN condition RPAREN
            {
              $$ = "(#{($2).as(String)})"
            }
         | predicate
            {
              $$ = ($1).as(String)
            }
         ;

predicate: expr comp_op expr
           {
             $$ = "#{($1).as(String)} #{($2).as(String)} #{($3).as(String)}"
           }
         ;

comp_op: EQ { $$ = "=" }
       | NE { $$ = "!=" }
       | LT { $$ = "<" }
       | GT { $$ = ">" }
       | LE { $$ = "<=" }
       | GE { $$ = ">=" }
       ;

expr: IDENT
       {
         $$ = ($1).as(String)
       }
    | NUMBER
       {
         $$ = ($1).as(String)
       }
    | STRING
       {
         $$ = ($1).as(String)
       }
    ;

%%

class SqlParser
  def query : String?
    @query
  end
end

if PROGRAM_NAME.ends_with?("sql_parser")
  parser = SqlParser.run
  if (query = parser.query)
    puts query
  end
end
