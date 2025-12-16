# frozen_string_literal: true

module Collie
  module Linter
    module Rules
      # Detects potentially redundant epsilon productions
      class RedundantEpsilon < Base
        self.rule_name = "RedundantEpsilon"
        self.description = "Detects potentially redundant epsilon (empty) productions"
        self.severity = :info
        self.autocorrectable = false

        def check(ast, _context = {})
          ast.rules.each do |rule|
            check_rule(rule)
          end

          @offenses
        end

        private

        def check_rule(rule)
          epsilon_alternatives = rule.alternatives.select { |alt| alt.symbols.empty? }
          return if epsilon_alternatives.empty?

          # Only report if there are other non-epsilon alternatives
          non_epsilon_alternatives = rule.alternatives.reject { |alt| alt.symbols.empty? }
          return if non_epsilon_alternatives.empty?

          epsilon_alternatives.each do |alt|
            add_offense(
              alt,
              message: "Rule '#{rule.name}' has an epsilon production. " \
                       "Verify if it's necessary or if the rule can be made optional elsewhere."
            )
          end
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::RedundantEpsilon)
