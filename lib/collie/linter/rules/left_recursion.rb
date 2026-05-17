# frozen_string_literal: true

module Collie
  module Linter
    module Rules
      # Detects left recursion in grammar rules
      class LeftRecursion < Base
        self.rule_name = "LeftRecursion"
        self.description = "Notes left recursion for LL parser portability"
        self.severity = :info
        self.autocorrectable = false

        def check(ast, _context = {})
          analyzer = Analyzer::Recursion.new(ast)
          result = analyzer.analyze

          result[:left_recursive].each do |rule_name|
            rule = ast.rules.find { |r| r.name == rule_name }
            next unless rule

            add_offense(
              rule,
              message: "Rule '#{rule_name}' uses left recursion. This is normal for LR parsers; " \
                       "review only if targeting LL parser portability."
            )
          end

          @offenses
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::LeftRecursion)
