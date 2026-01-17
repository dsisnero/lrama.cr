%{
int helper(int value) {
  return value + 1;
}
%}
%token NUMBER
%%
program
  : NUMBER { $$ = helper($1); }
  ;
%%
