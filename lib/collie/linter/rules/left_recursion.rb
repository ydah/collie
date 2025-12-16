# frozen_string_literal: true

module Collie
  module Linter
    module Rules
      # Detects left recursion in grammar rules
      class LeftRecursion < Base
        self.rule_name = "LeftRecursion"
        self.description = "Detects left recursion (may cause issues with some parsers)"
        self.severity = :warning
        self.autocorrectable = false

        def check(ast, _context = {})
          analyzer = Analyzer::Recursion.new(ast)
          result = analyzer.analyze

          result[:left_recursive].each do |rule_name|
            rule = ast.rules.find { |r| r.name == rule_name }
            next unless rule

            add_offense(
              rule,
              message: "Rule '#{rule_name}' uses left recursion (consider using right recursion for LL parsers)"
            )
          end

          @offenses
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::LeftRecursion)
