%token NUMBER IDENTIFIER UNUSED_TOKEN
%token NUMBER
%left '+' '-'

%%

expr
    : expr '+' expr
    | expr '-' expr
    | NUMBER
    | IDENTIFIER
    | UNDEFINED_SYMBOL
    ;

unused_rule
    : NUMBER
    ;

%%
