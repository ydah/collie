# frozen_string_literal: true

module Collie
  module Linter
    module Rules
      # Suggests improvements for %prec usage
      class PrecImprovement < Base
        self.rule_name = "PrecImprovement"
        self.description = "Suggests improvements for %prec directive usage"
        self.severity = :info
        self.autocorrectable = false

        def check(ast, _context = {})
          precedence_tokens = collect_precedence_tokens(ast)

          ast.rules.each do |rule|
            check_rule(rule, precedence_tokens)
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

        def check_rule(rule, precedence_tokens)
          rule.alternatives.each do |alt|
            next unless alt.prec

            # Check if the %prec token has a precedence declaration
            next if precedence_tokens.include?(alt.prec)

            add_offense(
              alt,
              message: "%%prec token '#{alt.prec}' is not declared in precedence directives. " \
                       "Consider adding it to %left, %right, or %nonassoc."
            )
          end
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::PrecImprovement)
