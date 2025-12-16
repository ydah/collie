// Bridge between JavaScript and Ruby Collie code

class CollieBridge {
  constructor(rubyRunner) {
    this.ruby = rubyRunner;
  }

  async lint(source) {
    const escapedSource = source.replace(/\\/g, '\\\\').replace(/'/g, "\\'");

    const rubyCode = `
      require 'json'

      source = '${escapedSource}'

      begin
        lexer = Collie::Parser::Lexer.new(source, filename: "playground.y")
        tokens = lexer.tokenize
        parser = Collie::Parser::Parser.new(tokens)
        ast = parser.parse

        symbol_table = Collie::Analyzer::SymbolTable.new
        ast.declarations.each do |decl|
          case decl
          when Collie::AST::TokenDeclaration
            decl.names.each do |name|
              symbol_table.add_token(name, type_tag: decl.type_tag, location: decl.location)
            rescue Collie::Error
              # Ignore duplicate declarations
            end
          when Collie::AST::ParameterizedRule
            symbol_table.add_nonterminal(decl.name, location: decl.location)
          end
        end

        ast.rules.each do |rule|
          symbol_table.add_nonterminal(rule.name, location: rule.location)
        end

        config = Collie::Config.new
        Collie::Linter::Registry.load_rules
        enabled_rules = Collie::Linter::Registry.enabled_rules(config)

        context = { symbol_table: symbol_table, source: source, file: "playground.y" }

        offenses = []
        enabled_rules.each do |rule_class|
          rule = rule_class.new(config.rule_config(rule_class.rule_name))
          offenses.concat(rule.check(ast, context))
        end

        result = offenses.map do |offense|
          location = offense.location || Collie::AST::Location.new(file: "playground.y", line: 1, column: 1)
          {
            severity: offense.severity.to_s,
            rule_name: offense.rule.rule_name,
            message: offense.message,
            location: {
              file: location.file,
              line: location.line,
              column: location.column
            },
            autocorrectable: offense.autocorrectable?
          }
        end

        JSON.generate(result)
      rescue => e
        JSON.generate([{
          severity: "error",
          rule_name: "ParseError",
          message: e.message,
          location: { file: "playground.y", line: 1, column: 1 },
          autocorrectable: false
        }])
      end
    `;

    const result = await this.ruby.eval(rubyCode);
    return JSON.parse(result.toString());
  }

  async format(source) {
    const escapedSource = source.replace(/\\/g, '\\\\').replace(/'/g, "\\'");

    const rubyCode = `
      source = '${escapedSource}'

      begin
        lexer = Collie::Parser::Lexer.new(source, filename: "playground.y")
        tokens = lexer.tokenize
        parser = Collie::Parser::Parser.new(tokens)
        ast = parser.parse

        config = Collie::Config.new
        formatter = Collie::Formatter::Formatter.new(
          Collie::Formatter::Options.new(config.formatter_options)
        )

        formatter.format(ast)
      rescue => e
        "Error: #{e.message}"
      end
    `;

    const result = await this.ruby.eval(rubyCode);
    return result.toString();
  }

  async autocorrect(source) {
    const escapedSource = source.replace(/\\/g, '\\\\').replace(/'/g, "\\'");

    const rubyCode = `
      source = '${escapedSource}'

      begin
        lexer = Collie::Parser::Lexer.new(source, filename: "playground.y")
        tokens = lexer.tokenize
        parser = Collie::Parser::Parser.new(tokens)
        ast = parser.parse

        symbol_table = Collie::Analyzer::SymbolTable.new
        ast.declarations.each do |decl|
          case decl
          when Collie::AST::TokenDeclaration
            decl.names.each do |name|
              symbol_table.add_token(name, type_tag: decl.type_tag, location: decl.location)
            rescue Collie::Error
              # Ignore
            end
          when Collie::AST::ParameterizedRule
            symbol_table.add_nonterminal(decl.name, location: decl.location)
          end
        end

        ast.rules.each do |rule|
          symbol_table.add_nonterminal(rule.name, location: rule.location)
        end

        context = { symbol_table: symbol_table, source: source, file: "playground.y" }

        config = Collie::Config.new
        Collie::Linter::Registry.load_rules
        enabled_rules = Collie::Linter::Registry.enabled_rules(config)

        offenses = []
        enabled_rules.each do |rule_class|
          rule = rule_class.new(config.rule_config(rule_class.rule_name))
          offenses.concat(rule.check(ast, context))
        end

        autocorrectable = offenses.select(&:autocorrectable?)
        autocorrectable.each { |offense| offense.autocorrect&.call }

        context[:source]
      rescue => e
        source
      end
    `;

    const result = await this.ruby.eval(rubyCode);
    return result.toString();
  }

  async getRules() {
    const rubyCode = `
      require 'json'

      Collie::Linter::Registry.load_rules

      rules = Collie::Linter::Registry.all.map do |rule_class|
        {
          name: rule_class.rule_name,
          description: rule_class.description,
          severity: rule_class.severity.to_s,
          autocorrectable: rule_class.autocorrectable
        }
      end

      JSON.generate(rules)
    `;

    const result = await this.ruby.eval(rubyCode);
    return JSON.parse(result.toString());
  }
}
