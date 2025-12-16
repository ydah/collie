# Collie Tutorial

This tutorial will guide you through using Collie to lint and format your grammar files.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Your First Grammar File](#your-first-grammar-file)
3. [Running the Linter](#running-the-linter)
4. [Understanding Lint Rules](#understanding-lint-rules)
5. [Auto-correcting Issues](#auto-correcting-issues)
6. [Configuring Collie](#configuring-collie)
7. [Formatting Grammar Files](#formatting-grammar-files)
8. [Working with Lrama Extensions](#working-with-lrama-extensions)
9. [CI Integration](#ci-integration)

## Getting Started

### Installation

Install Collie using RubyGems:

```bash
gem install collie
```

Verify the installation:

```bash
collie --version
```

### Project Setup

Create a new directory for your grammar project:

```bash
mkdir my-parser
cd my-parser
```

Initialize a Collie configuration file:

```bash
collie init
```

This creates a `.collie.yml` file with default settings.

## Your First Grammar File

Create a simple calculator grammar file called `calc.y`:

```yacc
%token NUMBER
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
```

## Running the Linter

Lint your grammar file:

```bash
collie lint calc.y
```

Auto-fix issues where possible:

```bash
collie lint -a calc.y
```

You should see output indicating any issues found. For the example above, you might see:

```
calc.y
  14:1: warning: [LeftRecursion] Rule 'expr' uses left recursion (consider using right recursion for LL parsers)

1 warning(s) found
```

This is informational - left recursion is actually good for LR parsers like Lrama!

### Understanding the Output

Each offense shows:
- File and location: `calc.y:14:1`
- Severity: `warning`, `error`, `convention`, or `info`
- Rule name: `[LeftRecursion]`
- Message: Description of the issue

## Understanding Lint Rules

### Error Rules (Must Fix)

These indicate actual problems with your grammar:

```yacc
# DuplicateToken - Token defined twice
%token NUMBER
%token NUMBER  # Error: duplicate definition

# UndefinedSymbol - Using undeclared token
expr: PLUS UNDEFINED  # Error: UNDEFINED not declared

# CircularReference - Infinite recursion
rule_a: rule_b ;
rule_b: rule_a ;  # Error: circular reference with no base case
```

### Warning Rules (Should Fix)

These indicate potential issues:

```yacc
# UnusedToken - Token declared but never used
%token UNUSED_TOKEN  # Warning: never referenced in rules

# AmbiguousPrecedence - Operator without precedence
expr: expr '+' expr ;  # Warning: '+' has no %left/%right/%nonassoc declaration
```

### Convention Rules (Style)

These enforce naming conventions:

```yacc
# TokenNaming - Tokens should be UPPER_CASE
%token Number  # Convention: should be NUMBER

# NonterminalNaming - Nonterminals should be snake_case
ExprStmt: expr SEMICOLON ;  # Convention: should be expr_stmt
```

### Info Rules (Optimization Hints)

These suggest potential improvements:

```yacc
# FactorizableRules - Common prefix can be factored
stmt
    : IF LPAREN expr RPAREN stmt
    | IF LPAREN expr RPAREN stmt ELSE stmt
    ;
# Info: Consider factoring the common IF LPAREN expr RPAREN prefix

# RedundantEpsilon - Potentially unnecessary empty production
optional_item
    : item
    |  /* empty */
    ;
# Info: Consider using the optional item where it's used instead
```

## Auto-correcting Issues

Collie can automatically fix certain issues with the `-a` or `--autocorrect` flag:

```bash
collie lint -a calc.y
```

### Autocorrectable Rules

The following rules support autocorrect:

- `TrailingWhitespace`: Removes trailing spaces and tabs from lines
- `EmptyAction`: Removes unnecessary empty action blocks `{ }`

When you run with `-a`, Collie will:
1. Detect all offenses in your grammar file
2. Apply fixes for autocorrectable offenses
3. Write the corrected source back to the file
4. Show how many offenses were auto-corrected

Example output:
```
calc.y
  5:15: convention: [TrailingWhitespace] Trailing whitespace detected
  12:1: convention: [EmptyAction] Empty action block can be removed

Auto-corrected 2 offense(s) in calc.y
```

### Combining with Other Options

You can combine autocorrect with other options:

```bash
# Autocorrect only specific rules
collie lint -a --only TrailingWhitespace calc.y

# Autocorrect all except specific rules
collie lint -a --except EmptyAction calc.y

# Autocorrect multiple files
collie lint -a **/*.y
```

## Configuring Collie

Edit your `.collie.yml` to customize behavior:

### Disabling Specific Rules

```yaml
rules:
  LeftRecursion:
    enabled: false  # Don't warn about left recursion
```

### Configuring Rule Options

```yaml
rules:
  LongRule:
    enabled: true
    max_alternatives: 15  # Allow up to 15 alternatives (default: 10)

  TokenNaming:
    enabled: true
    pattern: '^[A-Z][A-Z0-9_]*$'  # Custom regex pattern
```

### Formatter Options

```yaml
formatter:
  indent_size: 2              # Number of spaces for indentation
  align_tokens: true          # Align token declarations
  align_alternatives: true    # Align rule alternatives
  blank_lines_around_sections: 1  # Blank lines before/after %%
  max_line_length: 100        # Maximum line length
```

### Excluding Files

```yaml
exclude:
  - 'vendor/**/*'
  - 'generated/**/*'
  - 'tmp/**/*'
```

## Formatting Grammar Files

### Check Formatting

See if your file needs formatting without modifying it:

```bash
collie fmt --check calc.y
```

Exit code 0 means properly formatted, 1 means formatting needed.

### Show Formatting Changes

View the diff of what would change:

```bash
collie fmt --diff calc.y
```

Output shows unified diff:

```diff
 %token NUMBER
-%token PLUS MINUS TIMES DIVIDE
+%token PLUS
+%token MINUS
+%token TIMES
+%token DIVIDE
```

### Apply Formatting

Format the file in-place:

```bash
collie fmt calc.y
```

### Formatted Output Example

Before:

```yacc
%token   NUMBER PLUS    MINUS
%left PLUS    MINUS
%%
expr:expr PLUS expr|NUMBER;
%%
```

After:

```yacc
%token NUMBER
%token PLUS
%token MINUS

%left PLUS MINUS

%%

expr
    : expr PLUS expr
    | NUMBER
    ;

%%
```

## Working with Lrama Extensions

Lrama extends Yacc/Bison with powerful features. Collie fully supports them.

### Parameterized Rules

Define reusable rule templates:

```yacc
%rule pair(X, Y): X COMMA Y
    { $$ = make_pair($1, $3); }
    ;

%%

# Use the template with different types
number_pair: pair(NUMBER, NUMBER) ;
string_pair: pair(STRING, STRING) ;
```

### Named References

Use descriptive names instead of positional references:

```yacc
assignment
    : IDENTIFIER[var] EQUALS expr[value]
        { assign_variable($var, $value); }
    ;

# Instead of:
# : IDENTIFIER EQUALS expr { assign_variable($1, $3); }
```

### Inline Rules

Mark rules for inline expansion:

```yacc
%inline opt(X)
    : /* empty */
    | X
    ;

%%

# This:
optional_semicolon: opt(SEMICOLON) ;

# Expands to:
optional_semicolon
    : /* empty */
    | SEMICOLON
    ;
```

### Full Example with Lrama Features

```yacc
%token NUMBER IDENTIFIER
%token LPAREN RPAREN COMMA

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
    ;

%%
```

## CI Integration

### GitHub Actions

Add Collie to your GitHub Actions workflow.

Create `.github/workflows/lint.yml`:

```yaml
name: Lint Grammar Files

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  lint:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v4

    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: '3.4'

    - name: Install Collie
      run: gem install collie

    - name: Lint grammar files
      run: collie lint **/*.y

    - name: Check formatting
      run: collie fmt --check **/*.y
```

### Use Reusable Workflow

For a simpler setup, use Collie's reusable workflow:

```yaml
name: Lint Grammar Files

on: [push, pull_request]

jobs:
  lint:
    uses: ydah/collie/.github/workflows/lint.yml@main
    with:
      files: 'src/**/*.y'
      config: '.collie.yml'
      fail-on-warnings: false
```

### Pre-commit Hook

Add a git pre-commit hook to lint before committing.

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash

# Lint staged .y files
git diff --cached --name-only --diff-filter=ACM | grep '\.y$' | while read file; do
  collie lint "$file"
  if [ $? -ne 0 ]; then
    echo "Lint failed for $file"
    exit 1
  fi
done
```

Make it executable:

```bash
chmod +x .git/hooks/pre-commit
```

## Best Practices

### 1. Start with Default Rules

Begin with all rules enabled, then disable specific ones based on your needs.

### 2. Use Consistent Naming

Follow these conventions:
- Tokens: `UPPER_CASE` (e.g., `NUMBER`, `IDENTIFIER`)
- Nonterminals: `snake_case` (e.g., `expr_stmt`, `function_call`)
- Type tags: Consistent style (all `snake_case` or all `camelCase`)

### 3. Declare Precedence

Always declare precedence for operators:

```yacc
%left '+' '-'
%left '*' '/'
%right '^'
%nonassoc UMINUS  # Unary minus
```

### 4. Document Complex Rules

Add comments for non-obvious grammar rules:

```yacc
# Function definition with optional parameter list
function_def
    : DEF IDENTIFIER opt_params block
        { $$ = make_function($2, $3, $4); }
    ;
```

### 5. Run Collie Regularly

Add to your development workflow:

```bash
# Before committing
collie lint **/*.y && collie fmt **/*.y

# In CI
collie lint --format github **/*.y
```

## Troubleshooting

### "Parser error: unexpected token"

Your grammar file has syntax errors. Check:
- Matching braces in actions `{ }`
- Proper section separators `%%`
- Valid token/nonterminal names

### "No offenses detected" but file has issues

Check if the rule is enabled in `.collie.yml`:

```yaml
rules:
  RuleName:
    enabled: true
```

### Formatting produces unexpected output

File a bug report with:
1. Original file content
2. Expected output
3. Actual output
4. Your `.collie.yml` configuration

## Next Steps

- Read the [Configuration Guide](CONFIGURATION.md) for advanced config options
- Check the [Rule Reference](RULES.md) for detailed rule descriptions
- Explore [examples/](../examples/) for real-world grammar files
- Join the discussion on [GitHub](https://github.com/ydah/collie)

Happy parsing!
