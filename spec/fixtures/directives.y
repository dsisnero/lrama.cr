%define api.value.type {int}
%locations
%token <int> NUMBER
%start program
%%
program
  : NUMBER
  ;
%%
