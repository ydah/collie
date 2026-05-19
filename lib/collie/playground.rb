# frozen_string_literal: true

require "json"

module Collie
  # Browser-facing API used by the static playground.
  module Playground
    DEFAULT_FILENAME = "playground.y"

    ParseErrorRule = Struct.new(:rule_name)
    PARSE_ERROR_RULE = ParseErrorRule.new("ParseError")

    class << self
      def lint(payload = {})
        source, filename = source_payload(payload)
        config = Config.new
        ast = parse_source(source, filename: filename)
        context = build_context(ast, source, filename)
        offenses = run_lint_rules(ast, context, config)

        success_response(diagnostics: serialize_offenses(offenses))
      rescue Error => e
        success_response(ok: false, diagnostics: [parse_error_diagnostic(filename, e.message)])
      end

      def format(payload = {})
        source, filename = source_payload(payload)
        config = Config.new
        formatted = format_source(source, filename: filename, config: config)

        success_response(formatted: formatted, changed: formatted != source)
      rescue Error => e
        success_response(ok: false, diagnostics: [parse_error_diagnostic(filename, e.message)])
      end

      def autocorrect(payload = {})
        source, filename = source_payload(payload)
        config = Config.new
        ast = parse_source(source, filename: filename)
        context = build_context(ast, source, filename)
        offenses = run_lint_rules(ast, context, config)
        autocorrectable = offenses.select(&:autocorrectable?)

        autocorrectable.each { |offense| offense.autocorrect&.call }

        success_response(source: context[:source], applied: autocorrectable.size)
      rescue Error => e
        success_response(ok: false, source: source.to_s, diagnostics: [parse_error_diagnostic(filename, e.message)])
      end

      def rules(_payload = {})
        Linter::Registry.load_rules

        serialized_rules = Linter::Registry.all.map do |rule_class|
          {
            name: rule_class.rule_name,
            description: rule_class.description,
            severity: rule_class.severity.to_s,
            autocorrectable: rule_class.autocorrectable
          }
        end

        JSON.generate(rules: serialized_rules.sort_by { |rule| rule[:name] })
      end

      private

      def source_payload(payload)
        source = payload.fetch("source", "")
        filename = payload.fetch("filename", DEFAULT_FILENAME)

        [source.to_s, filename.to_s]
      end

      def parse_source(source, filename:)
        lexer = Parser::Lexer.new(source, filename: filename)
        tokens = lexer.tokenize
        parser = Parser::Parser.new(tokens)
        parser.parse
      end

      def build_context(ast, source, filename)
        symbol_table = build_symbol_table(ast)
        Analyzer::SymbolResolver.resolve(ast, symbol_table)
        { symbol_table: symbol_table, source: source, file: filename }
      end

      def build_symbol_table(ast)
        symbol_table = Analyzer::SymbolTable.new

        ast.declarations.each do |decl|
          case decl
          when AST::TokenDeclaration
            decl.names.each do |name|
              add_token(symbol_table, name, type_tag: decl.type_tag, location: decl.location)
            end
          when AST::PrecedenceDeclaration
            decl.tokens.each do |name|
              add_token(symbol_table, name, location: decl.location)
            end
          when AST::ParameterizedRule
            symbol_table.add_nonterminal(decl.name, location: decl.location)
          when AST::InlineRule
            symbol_table.add_nonterminal(decl.rule, location: decl.location)
          end
        end

        ast.rules.each do |rule|
          symbol_table.add_nonterminal(rule.name, location: rule.location)
        end

        symbol_table
      end

      def add_token(symbol_table, name, type_tag: nil, location: nil)
        symbol_table.add_token(name, type_tag: type_tag, location: location)
      rescue Error
        # Duplicate declarations are reported by lint rules; keep the resolver table usable.
      end

      def run_lint_rules(ast, context, config)
        Linter::Registry.load_rules

        Linter::Registry.enabled_rules(config).flat_map do |rule_class|
          rule = rule_class.new(config.rule_config(rule_class.rule_name))
          rule.check(ast, context)
        end
      end

      def format_source(source, filename:, config:)
        ast = parse_source(source, filename: filename)
        formatter = Formatter::Formatter.new(Formatter::Options.new(config.formatter_options))
        formatted = formatter.format(ast)
        formatted_ast = parse_source(formatted, filename: filename)

        return formatted if Formatter::Signature.build(ast) == Formatter::Signature.build(formatted_ast)

        raise Error, "Formatted output changed grammar structure"
      end

      def success_response(ok: true, diagnostics: [], **payload)
        JSON.generate({
          ok: ok,
          diagnostics: diagnostics,
          summary: diagnostics_summary(diagnostics)
        }.merge(payload))
      end

      def diagnostics_summary(diagnostics)
        {
          total: diagnostics.length,
          autocorrectable: diagnostics.count { |diagnostic| diagnostic[:autocorrectable] },
          by_severity: diagnostics.group_by { |diagnostic| diagnostic[:severity] }.transform_values(&:count)
        }
      end

      def serialize_offenses(offenses)
        offenses.map { |offense| serialize_offense(offense) }
      end

      def serialize_offense(offense)
        location = offense.location || AST::Location.new(file: DEFAULT_FILENAME, line: 1, column: 1)

        {
          severity: offense.severity.to_s,
          rule_name: offense.rule.rule_name,
          message: offense.message,
          location: serialize_location(location),
          autocorrectable: offense.autocorrectable?
        }
      end

      def serialize_location(location)
        {
          file: location.file,
          line: location.line,
          column: location.column,
          length: location.length
        }
      end

      def parse_error_diagnostic(file, message)
        {
          severity: "error",
          rule_name: PARSE_ERROR_RULE.rule_name,
          message: message,
          location: serialize_location(parse_error_location(file, message)),
          autocorrectable: false
        }
      end

      def parse_error_location(file, message)
        match = message.match(/:(\d+):(\d+)\b/)
        line = match ? match[1].to_i : 1
        column = match ? match[2].to_i : 1

        AST::Location.new(file: file, line: line, column: column, length: 1)
      end
    end
  end
end
