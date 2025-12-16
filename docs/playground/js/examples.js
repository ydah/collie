// Example grammar files for the playground

const EXAMPLES = {
  simple: {
    name: 'Simple Calculator',
    code: `%token NUMBER
%token PLUS MINUS TIMES DIVIDE
%token LPAREN RPAREN

%left PLUS MINUS
%left TIMES DIVIDE

%%

program
    : expr
    ;

expr
    : expr PLUS expr    { $$ = $1 + $3; }
    | expr MINUS expr   { $$ = $1 - $3; }
    | expr TIMES expr   { $$ = $1 * $3; }
    | expr DIVIDE expr  { $$ = $1 / $3; }
    | LPAREN expr RPAREN { $$ = $2; }
    | NUMBER            { $$ = $1; }
    ;

%%
`
  },

  lrama: {
    name: 'Lrama Features Demo',
    code: `%token NUMBER IDENTIFIER
%token LPAREN RPAREN COMMA

%rule pair(X, Y): X COMMA Y ;
%rule list(X): X | list(X) COMMA X ;

%%

program
    : function_call
    ;

function_call
    : IDENTIFIER[func] LPAREN argument_list RPAREN
        { call_function($func, $3); }
    ;

argument_list
    : list(expr)
    | /* empty */  { $$ = empty_list(); }
    ;

expr
    : NUMBER[n]         { $$ = make_number($n); }
    | IDENTIFIER[id]    { $$ = make_variable($id); }
    | pair(NUMBER, NUMBER)
    ;

%%
`
  },

  invalid: {
    name: 'Invalid Grammar (Demo)',
    code: `%token NUMBER
%token NUMBER

%%

expr: UNDEFINED_TOKEN ;

unused_rule: NUMBER ;

%%
`
  }
};
