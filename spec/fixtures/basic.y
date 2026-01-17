%token NUMBER PLUS
%left PLUS
%%
expr
  : expr PLUS expr { $$ = $1 + $3; }
  | NUMBER
  ;
%%
