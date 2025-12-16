%token NUMBER IDENTIFIER PLUS MINUS TIMES DIVIDE
%left PLUS MINUS
%left TIMES DIVIDE

%%

expr
    : expr PLUS expr
    | expr MINUS expr
    | expr TIMES expr
    | expr DIVIDE expr
    | NUMBER
    | IDENTIFIER
    ;

%%
