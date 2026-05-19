# Collie

A linter and formatter for Lrama Style BNF grammar files (`.y` files).

[![CI](https://github.com/ydah/collie/workflows/CI/badge.svg)](https://github.com/ydah/collie/actions)
[![Gem Version](https://badge.fury.io/rb/collie.svg)](https://badge.fury.io/rb/collie)

Collie checks grammar files for common mistakes, formats them consistently, and supports Lrama-specific syntax such as parameterized rules, named references, and inline rules.

## Installation

```bash
gem install collie
```

Or add it to your Gemfile:

```ruby
gem "collie", require: false
```

Collie requires Ruby 3.2 or newer.

## Quick Start

```bash
# Lint files, globs, or directories
collie lint parse.y
collie lint "src/**/*.y"
collie lint grammars/

# Format
collie fmt parse.y
collie fmt --check parse.y
collie fmt --diff parse.y

# Auto-correct supported lint offenses
collie lint -a parse.y

# Inspect rules
collie rules
collie explain DuplicateToken
```

## Configuration

Generate a config file:

```bash
collie init
collie init --profile lrama
collie init --profile strict --path .collie.yml
```

Profiles: `default`, `lrama`, `bison`, `strict`, `minimal`.

Minimal `.collie.yml`:

```yaml
include:
  - "src/**/*.y"
exclude:
  - "vendor/**/*"

formatter:
  indent_size: 2
  max_line_length: 120

rules:
  TokenNaming:
    severity: convention
  LeftRecursion:
    enabled: false
```

## Commands

| Command | Purpose |
| --- | --- |
| `collie lint [OPTIONS] FILES` | Lint grammar files. Supports `--format text\|json\|github\|sarif`, `--fail-level`, `--only`, `--except`, `--stdin`, and `--autocorrect`. |
| `collie fmt [OPTIONS] FILES` | Format grammar files. Supports `--check`, `--diff`, `--config`, and `--stdin`. |
| `collie rules [--format text\|json]` | List available lint rules. |
| `collie explain RULE [--format text\|json]` | Show rule metadata. |
| `collie config-schema` | Print the JSON Schema for `.collie.yml`. |
| `collie tokens FILE` | Print lexer tokens as JSON. |
| `collie ast FILE` | Print the parsed AST as JSON. |
| `collie version` | Print the installed version. |

Run `collie help COMMAND` for all options.

## CI

Use the reusable GitHub Actions workflow:

```yaml
name: Lint Grammar Files

on: [push, pull_request]

jobs:
  lint:
    uses: ydah/collie/.github/workflows/lint.yml@main
    with:
      files: "src/**/*.y"
      config: ".collie.yml"
      fail-on-warnings: true
```

For code scanning integrations:

```bash
collie lint --format sarif parse.y
```

## Development

```bash
bundle install
bundle exec rspec
bundle exec rake
```

## Documentation

- [Tutorial](docs/TUTORIAL.md)
- [Changelog](CHANGELOG.md)

## License

MIT License. See [LICENSE.txt](LICENSE.txt).
