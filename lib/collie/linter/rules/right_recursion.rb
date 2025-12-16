# frozen_string_literal: true

module Collie
  module Linter
    module Rules
      # Detects right recursion and suggests left recursion conversion
      class RightRecursion < Base
        self.rule_name = "RightRecursion"
        self.description = "Detects right recursion (consider converting to left recursion for LR parsers)"
        self.severity = :warning
        self.autocorrectable = false

        def check(ast, _context = {})
          analyzer = Analyzer::Recursion.new(ast)
          result = analyzer.analyze

          result[:right_recursive].each do |rule_name|
            rule = ast.rules.find { |r| r.name == rule_name }
            next unless rule

            add_offense(
              rule,
              message: "Rule '#{rule_name}' uses right recursion " \
                       "(consider left recursion for better LR parser performance)"
            )
          end

          @offenses
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::RightRecursion)
