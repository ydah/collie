/* Lrama extension features example */

%token NUMBER IDENTIFIER COMMA EQUALS

/* Parameterized rule declaration */
%rule pair(X, Y): X COMMA Y ;

%%

/* Parameterized rule definition */
number_pair(A, B)
    : A COMMA B { $$ = make_pair($1, $3); }
    ;

/* Named references in simple rule */
assignment
    : IDENTIFIER[var] EQUALS NUMBER[value] { assign($var, $value); }
    ;

/* Regular rule for start */
start
    : assignment
    | NUMBER
    ;

%%

/* Epilogue */
