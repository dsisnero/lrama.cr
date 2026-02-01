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

%token SELECT DISTINCT FROM WHERE AND OR NOT AS
%token JOIN LEFT RIGHT INNER OUTER ON
%token GROUP BY ORDER LIMIT OFFSET ASC DESC
%token COMMA STAR SEMICOLON LPAREN RPAREN
%token EQ NE LT GT LE GE
%token IDENT STRING NUMBER

%left OR
%left AND
%right NOT
%left EQ NE LT GT LE GE

%lexer {
  keywords case_insensitive SELECT DISTINCT FROM WHERE AND OR NOT AS JOIN LEFT RIGHT INNER OUTER ON GROUP BY ORDER LIMIT OFFSET ASC DESC
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
          set_query(s($1))
        }
     ;

select_stmt: SELECT distinct_opt select_list FROM table_ref join_list where_clause group_clause order_clause limit_clause
              {
                $$ = "SELECT#{s($2)} #{s($3)} FROM #{s($5)}#{s($6)}#{s($7)}#{s($8)}#{s($9)}#{s($10)}"
              }
           ;

distinct_opt: /* empty */
               {
                 $$ = ""
               }
            | DISTINCT
               {
                 $$ = " DISTINCT"
               }
            ;

select_list: STAR
              {
                $$ = "*"
              }
           | column_list
              {
                $$ = s($1)
              }
           ;

column_list: column_ref
              {
                $$ = s($1)
              }
           | column_list COMMA column_ref
              {
                $$ = "#{s($1)}, #{s($3)}"
              }
           ;

column_ref: IDENT
             {
               $$ = s($1)
             }
          | IDENT AS IDENT
             {
               $$ = "#{s($1)} AS #{s($3)}"
             }
          | IDENT IDENT
             {
               $$ = "#{s($1)} #{s($2)}"
             }
          ;

table_ref: IDENT
            {
              $$ = s($1)
            }
         | IDENT AS IDENT
            {
              $$ = "#{s($1)} AS #{s($3)}"
            }
         | IDENT IDENT
            {
              $$ = "#{s($1)} #{s($2)}"
            }
         ;

join_list: /* empty */
            {
              $$ = ""
            }
         | join_clause
            {
              $$ = " #{s($1)}"
            }
         | join_list join_clause
            {
              $$ = "#{s($1)} #{s($2)}"
            }
         ;

join_clause: join_type JOIN table_ref ON condition
              {
                prefix = s($1)
                prefix = prefix.empty? ? "" : "#{prefix} "
                $$ = "#{prefix}JOIN #{s($3)} ON #{s($5)}"
              }
           ;

join_type: /* empty */
            {
              $$ = ""
            }
         | INNER
            {
              $$ = "INNER"
            }
         | LEFT
            {
              $$ = "LEFT"
            }
         | RIGHT
            {
              $$ = "RIGHT"
            }
         | LEFT OUTER
            {
              $$ = "LEFT OUTER"
            }
         | RIGHT OUTER
            {
              $$ = "RIGHT OUTER"
            }
         ;

where_clause: /* empty */
               {
                 $$ = ""
               }
            | WHERE condition
               {
                 $$ = " WHERE #{s($2)}"
               }
            ;

group_clause: /* empty */
               {
                 $$ = ""
               }
            | GROUP BY group_list
               {
                 $$ = " GROUP BY #{s($3)}"
               }
            ;

group_list: column_ref
             {
               $$ = s($1)
             }
          | group_list COMMA column_ref
             {
               $$ = "#{s($1)}, #{s($3)}"
             }
          ;

order_clause: /* empty */
               {
                 $$ = ""
               }
            | ORDER BY order_list
               {
                 $$ = " ORDER BY #{s($3)}"
               }
            ;

order_list: order_item
             {
               $$ = s($1)
             }
          | order_list COMMA order_item
             {
               $$ = "#{s($1)}, #{s($3)}"
             }
          ;

order_item: column_ref order_dir
             {
               $$ = "#{s($1)}#{s($2)}"
             }
          ;

order_dir: /* empty */
            {
              $$ = ""
            }
         | ASC
            {
              $$ = " ASC"
            }
         | DESC
            {
              $$ = " DESC"
            }
         ;

limit_clause: /* empty */
              {
                $$ = ""
              }
           | LIMIT NUMBER offset_clause
              {
                $$ = " LIMIT #{s($2)}#{s($3)}"
              }
           ;

offset_clause: /* empty */
               {
                 $$ = ""
               }
            | OFFSET NUMBER
               {
                 $$ = " OFFSET #{s($2)}"
               }
            ;

condition: condition AND condition
            {
              $$ = "(#{s($1)} AND #{s($3)})"
            }
         | condition OR condition
            {
              $$ = "(#{s($1)} OR #{s($3)})"
            }
         | NOT condition
            {
              $$ = "(NOT #{s($2)})"
            }
         | LPAREN condition RPAREN
            {
              $$ = "(#{s($2)})"
            }
         | predicate
            {
              $$ = s($1)
            }
         ;

predicate: expr comp_op expr
           {
             $$ = "#{s($1)} #{s($2)} #{s($3)}"
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
         $$ = s($1)
       }
    | NUMBER
       {
         $$ = s($1)
       }
    | STRING
       {
         $$ = s($1)
       }
    ;

%%

class SqlParser
  def s(value : Lrama::Runtime::Value) : String
    value.as(String)
  end

  def set_query(value : String)
    @query = value
  end

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
