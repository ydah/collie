# frozen_string_literal: true

module Collie
  module Linter
    module Rules
      # Detects operators without explicit precedence declarations
      class AmbiguousPrecedence < Base
        self.rule_name = "AmbiguousPrecedence"
        self.description = "Detects operators without explicit precedence declarations"
        self.severity = :warning
        self.autocorrectable = false

        # Common operator patterns (may be quoted or unquoted)
        OPERATOR_PATTERNS = [
          %r{^'[+\-*/%^&|<>=!]+'$}, # Quoted single-character operators
          %r{^"[+\-*/%^&|<>=!]+"$}, # Double-quoted single-character operators
          %r{^[+\-*/%^&|<>=!]+$}, # Unquoted symbolic operators
          /^'(==|!=|<=|>=|<<|>>|\|\||&&)'$/, # Quoted multi-character operators
          /^"(==|!=|<=|>=|<<|>>|\|\||&&)"$/, # Double-quoted multi-character operators
          /^(==|!=|<=|>=|<<|>>|\|\||&&)$/ # Unquoted multi-character operators
        ].freeze

        def check(ast, _context = {})
          precedence_tokens = collect_precedence_tokens(ast)
          operators = collect_operators(ast)

          operators.each do |operator, locations|
            next if precedence_tokens.include?(operator)

            locations.each do |location|
              add_offense_at(
                location,
                message: "Operator '#{operator}' does not have an explicit precedence declaration"
              )
            end
          end

          @offenses
        end

        private

        def collect_precedence_tokens(ast)
          tokens = []
          ast.declarations.each do |decl|
            next unless decl.is_a?(AST::PrecedenceDeclaration)

            tokens.concat(decl.tokens)
          end
          tokens
        end

        def collect_operators(ast)
          operators = Hash.new { |h, k| h[k] = [] }

          ast.rules.each do |rule|
            rule.alternatives.each do |alt|
              alt.symbols.each do |symbol|
                next unless symbol.terminal?
                next unless looks_like_operator?(symbol.name)

                operators[symbol.name] << (symbol.location || rule.location)
              end
            end
          end

          operators
        end

        def looks_like_operator?(name)
          OPERATOR_PATTERNS.any? { |pattern| name.match?(pattern) }
        end

        def add_offense_at(location, message:)
          offense = Offense.new(
            rule: self.class,
            location: location,
            message: message
          )
          @offenses << offense
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::AmbiguousPrecedence)
