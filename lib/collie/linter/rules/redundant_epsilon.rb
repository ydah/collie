# frozen_string_literal: true

module Collie
  module Linter
    module Rules
      # Detects potentially redundant epsilon productions
      class RedundantEpsilon < Base
        self.rule_name = "RedundantEpsilon"
        self.description = "Detects duplicate epsilon (empty) productions"
        self.severity = :info
        self.autocorrectable = false

        def check(ast, _context = {})
          each_rule_like(ast) do |rule|
            check_rule(rule)
          end

          @offenses
        end

        private

        def check_rule(rule)
          epsilon_alternatives = rule.alternatives.select { |alt| epsilon?(alt) }
          return if epsilon_alternatives.size < 2

          epsilon_alternatives.drop(1).each do |alt|
            add_offense(
              alt,
              message: "Rule '#{rule_like_name(rule)}' has multiple epsilon productions. " \
                       "Keep one empty alternative and remove duplicates."
            )
          end
        end

        def epsilon?(alternative)
          alternative.symbols.empty? || alternative.explicit_empty
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::RedundantEpsilon)
