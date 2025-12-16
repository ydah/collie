# Collie

A linter and formatter for Lrama Style BNF grammar files (.y files). Collie helps you write clean, maintainable, and error-free grammar files for parser generators like Lrama, Yacc, and Bison.

[![CI](https://github.com/ydah/collie/workflows/CI/badge.svg)](https://github.com/ydah/collie/actions)
[![Gem Version](https://badge.fury.io/rb/collie.svg)](https://badge.fury.io/rb/collie)

## Features

- 18 Built-in Lint Rules - Catch common errors and suggest improvements
- Lrama Extension Support - Full support for parameterized rules, named references, and inline rules
- Smart Formatting - Consistent indentation, alignment, and spacing
- Configurable - Customize rules and formatting options via `.collie.yml`
- Multiple Output Formats - Text, JSON, and GitHub Actions annotations
- Auto-correction - Automatically fix certain issues

## Installation

```bash
gem install collie
```

Or add to your Gemfile:

```ruby
gem 'collie', require: false
```

## Quick Start

### Try Online

Try Collie in your browser without installing anything:

[Open Playground](https://ydah.github.io/collie/playground/) (Coming soon)

### Lint a grammar file

```bash
# Check for issues
collie lint parse.y

# Auto-fix issues where possible
collie lint -a parse.y
```

### Format a grammar file

```bash
# Check formatting
collie fmt --check parse.y

# Format in-place
collie fmt parse.y

# Show diff
collie fmt --diff parse.y
```

### List all available rules

```bash
collie rules
```

## Configuration

Create a `.collie.yml` file in your project root:

```yaml
# Inherit from another config (optional)
inherit_from: .collie_base.yml

# Rule configuration
rules:
  DuplicateToken:
    enabled: true
    severity: error

  TokenNaming:
    enabled: true
    severity: convention
    pattern: '^[A-Z][A-Z0-9_]*$'

  LongRule:
    enabled: true
    max_alternatives: 10

  # Disable specific rules
  LeftRecursion:
    enabled: false

# Formatter options
formatter:
  indent_size: 4
  align_tokens: true
  align_alternatives: true
  blank_lines_around_sections: 2
  max_line_length: 120

# File patterns
include:
  - '**/*.y'
exclude:
  - 'vendor/**/*'
  - 'tmp/**/*'
```

## Available Rules

### Validation Rules (Error)

| Rule | Description | Auto-fix |
|------|-------------|----------|
| `DuplicateToken` | Token defined multiple times | No |
| `UndefinedSymbol` | Reference to undeclared token/nonterminal | No |
| `UnreachableRule` | Rule not derivable from start symbol | No |
| `CircularReference` | Infinite recursion in grammar | No |
| `MissingStartSymbol` | No `%start` declaration with ambiguous default | No |

### Warning Rules

| Rule | Description | Auto-fix |
|------|-------------|----------|
| `UnusedNonterminal` | Nonterminal defined but never referenced | No |
| `UnusedToken` | Token declared but never used | No |
| `LeftRecursion` | Detects left recursion (informational) | No |
| `RightRecursion` | Suggests left recursion conversion | No |
| `AmbiguousPrecedence` | Operators without explicit precedence | No |

### Style Rules (Convention)

| Rule | Description | Auto-fix |
|------|-------------|----------|
| `TokenNaming` | Tokens should be UPPER_CASE | No |
| `NonterminalNaming` | Nonterminals should be snake_case | No |
| `ConsistentTagNaming` | Type tags should be consistent | No |
| `TrailingWhitespace` | No trailing whitespace at end of lines | Yes |
| `EmptyAction` | Warns on empty `{ }` actions | Yes |
| `LongRule` | Rule with too many alternatives | No |

### Optimization Rules (Info)

| Rule | Description | Auto-fix |
|------|-------------|----------|
| `FactorizableRules` | Suggests factoring common prefixes | No |
| `RedundantEpsilon` | Unnecessary epsilon productions | No |
| `PrecImprovement` | Suggests `%prec` improvements | No |

## Usage Examples

### Example Grammar File

```yacc
%token <node> CLASS MODULE DEF
%token <id> IDENTIFIER CONSTANT
%token <num> INTEGER FLOAT

%left '+' '-'
%left '*' '/'
%right '^'

%%

program
    : class_definition
    | module_definition
    ;

class_definition
    : CLASS CONSTANT '{' class_body '}'
        { $$ = make_class($2, $4); }
    ;

expr
    : expr '+' expr    { $$ = add($1, $3); }
    | expr '-' expr    { $$ = sub($1, $3); }
    | expr '*' expr    { $$ = mul($1, $3); }
    | '(' expr ')'     { $$ = $2; }
    | IDENTIFIER       { $$ = var($1); }
    | INTEGER          { $$ = num($1); }
    ;

%%
```

### Lrama Extensions

Collie fully supports Lrama-specific syntax:

```yacc
# Parameterized Rules
%rule pair(X, Y): X COMMA Y ;

number_pair
    : pair(NUMBER, NUMBER)
        { $$ = make_pair($1, $3); }
    ;

# Named References
assignment
    : IDENTIFIER[var] EQUALS NUMBER[value]
        { assign($var, $value); }
    ;

# Inline Rules
%inline opt(X): /* empty */ | X ;
```

### CI Integration (GitHub Actions)

Use the reusable workflow in your project:

```yaml
# .github/workflows/lint.yml
name: Lint Grammar Files

on: [push, pull_request]

jobs:
  lint:
    uses: ydah/collie/.github/workflows/lint.yml@main
    with:
      files: 'src/**/*.y'
      config: '.collie.yml'
      fail-on-warnings: true
```

### Programmatic Usage

```ruby
require 'collie'

# Parse a grammar file
parser = Collie::Parser::Parser.new(source_code)
ast = parser.parse

# Analyze the grammar
symbol_table = Collie::Analyzer::SymbolTable.new(ast)
symbol_table.build

# Run linter
config = Collie::Config.new
linter = Collie::Linter.new(config)
offenses = linter.lint(ast)

# Format the grammar
formatter = Collie::Formatter::Formatter.new(config.formatter_options)
formatted_code = formatter.format(ast)
```

## Command Line Options

### `collie lint`

```bash
collie lint [OPTIONS] FILES

Options:
  --config PATH         Path to config file (default: .collie.yml)
  --format FORMAT       Output format: text, json, github (default: text)
  -a, --autocorrect     Auto-fix offenses where possible
  --only RULES          Run only specified rules (comma-separated)
  --except RULES        Exclude specified rules (comma-separated)
```

### `collie fmt`

```bash
collie fmt [OPTIONS] FILES

Options:
  --config PATH         Path to config file
  --check               Check only, don't modify files
  --diff                Show diff of changes
```

### `collie rules`

```bash
collie rules [OPTIONS]

Options:
  --format FORMAT       Output format: text, json (default: text)
```

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop

# Run all checks
bundle exec rake
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Credits

Developed for improving the development experience with [Lrama](https://github.com/ruby/lrama), the next-generation parser generator for Ruby.

## Related Projects

### Editor Integration (Planned)

- collie-lsp - LSP (Language Server Protocol) implementation for Collie
- vscode-collie - VS Code extension for Collie

### Parser Generators

- [Lrama](https://github.com/ruby/lrama) - LALR (1) parser generator
- [Bison](https://www.gnu.org/software/bison/) - GNU parser generator

### Inspiration

- [RuboCop](https://github.com/rubocop/rubocop) - Ruby static code analyzer (inspiration for architecture)
