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
  token STRING /'[^']*'/ string
  token NUMBER /[0-9]+(?:\.[0-9]+)?/ string
  token IDENT /[A-Za-z_][A-Za-z0-9_]*/ string keyword
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
          set_tree(s($1))
        }
     ;

select_stmt: SELECT distinct_opt select_list FROM table_ref join_list where_clause group_clause order_clause limit_clause
              {
                $$ = node("SELECT", [
                  s($2),
                  s($3),
                  node("FROM", [s($5)]),
                  s($6),
                  s($7),
                  s($8),
                  s($9),
                  s($10),
                ])
              }
           ;

distinct_opt: /* empty */
               {
                 $$ = ""
               }
            | DISTINCT
               {
                 $$ = "DISTINCT"
               }
            ;

select_list: STAR
              {
                $$ = node("STAR", [] of String)
              }
           | column_list
              {
                $$ = node("COLUMNS", [s($1)])
              }
           ;

column_list: column_ref
              {
                $$ = s($1)
              }
           | column_list COMMA column_ref
              {
                $$ = node("COLUMNS", [s($1), s($3)])
              }
           ;

column_ref: IDENT
             {
               $$ = node("COLUMN #{s($1)}", [] of String)
             }
          | IDENT AS IDENT
             {
               $$ = node("COLUMN #{s($1)}", [node("AS #{s($3)}", [] of String)])
             }
          | IDENT IDENT
             {
               $$ = node("COLUMN #{s($1)}", [node("ALIAS #{s($2)}", [] of String)])
             }
          ;

table_ref: IDENT
            {
              $$ = node("TABLE #{s($1)}", [] of String)
            }
         | IDENT AS IDENT
            {
              $$ = node("TABLE #{s($1)}", [node("AS #{s($3)}", [] of String)])
            }
         | IDENT IDENT
            {
              $$ = node("TABLE #{s($1)}", [node("ALIAS #{s($2)}", [] of String)])
            }
         ;

join_list: /* empty */
            {
              $$ = ""
            }
         | join_clause
            {
              $$ = node("JOINS", [s($1)])
            }
         | join_list join_clause
            {
              $$ = node("JOINS", [s($1), s($2)])
            }
         ;

join_clause: join_type JOIN table_ref ON condition
              {
                label = s($1)
                label = label.empty? ? "JOIN" : "#{label} JOIN"
                $$ = node(label, [s($3), node("ON", [s($5)])])
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
                 $$ = node("WHERE", [s($2)])
               }
            ;

group_clause: /* empty */
               {
                 $$ = ""
               }
            | GROUP BY group_list
               {
                 $$ = node("GROUP BY", [s($3)])
               }
            ;

group_list: column_ref
             {
               $$ = s($1)
             }
          | group_list COMMA column_ref
             {
               $$ = node("GROUP BY", [s($1), s($3)])
             }
          ;

order_clause: /* empty */
               {
                 $$ = ""
               }
            | ORDER BY order_list
               {
                 $$ = node("ORDER BY", [s($3)])
               }
            ;

order_list: order_item
             {
               $$ = s($1)
             }
          | order_list COMMA order_item
             {
               $$ = node("ORDER BY", [s($1), s($3)])
             }
          ;

order_item: column_ref order_dir
             {
               dir = s($2)
               if dir.empty?
                 $$ = s($1)
               else
                 $$ = node("ORDER #{dir.strip}", [s($1)])
               end
             }
          ;

order_dir: /* empty */
            {
              $$ = ""
            }
         | ASC
            {
              $$ = "ASC"
            }
         | DESC
            {
              $$ = "DESC"
            }
         ;

limit_clause: /* empty */
              {
                $$ = ""
              }
           | LIMIT NUMBER offset_clause
              {
                $$ = node("LIMIT #{s($2)}", [s($3)])
              }
           ;

offset_clause: /* empty */
               {
                 $$ = ""
               }
            | OFFSET NUMBER
               {
                 $$ = node("OFFSET #{s($2)}", [] of String)
               }
            ;

condition: condition AND condition
            {
              $$ = node("AND", [s($1), s($3)])
            }
         | condition OR condition
            {
              $$ = node("OR", [s($1), s($3)])
            }
         | NOT condition
            {
              $$ = node("NOT", [s($2)])
            }
         | LPAREN condition RPAREN
            {
              $$ = s($2)
            }
         | predicate
            {
              $$ = s($1)
            }
         ;

predicate: expr comp_op expr
           {
             $$ = node("COMPARE #{s($2)}", [s($1), s($3)])
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
         $$ = node("IDENT #{s($1)}", [] of String)
       }
    | NUMBER
       {
         $$ = node("NUMBER #{s($1)}", [] of String)
       }
    | STRING
       {
         $$ = node("STRING #{s($1)}", [] of String)
       }
    ;

%%

class SqlParser
  def s(value : Lrama::Runtime::Value) : String
    value.as(String)
  end

  def node(label : String, children : Array(String)) : String
    cleaned = children.compact.select { |child| !child.empty? }
    return label if cleaned.empty?
    "#{label}\n#{cleaned.map { |child| indent(child) }.join("\n")}"
  end

  def indent(tree : String) : String
    tree.lines.map { |line| "  #{line}" }.join("\n")
  end

  def set_tree(value : String)
    @tree = value
  end

  def tree : String?
    @tree
  end
end

if PROGRAM_NAME.ends_with?("sql_parser")
  parser = SqlParser.run
  if (tree = parser.tree)
    puts tree
  end
end
