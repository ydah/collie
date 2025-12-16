# frozen_string_literal: true

module Collie
  module Linter
    module Rules
      # Detects rules with too many alternatives
      class LongRule < Base
        self.rule_name = "LongRule"
        self.description = "Detects rules with too many alternatives"
        self.severity = :convention
        self.autocorrectable = false

        DEFAULT_MAX_ALTERNATIVES = 10

        def check(ast, _context = {})
          max_alternatives = @config.dig("rules", "LongRule", "max_alternatives") || DEFAULT_MAX_ALTERNATIVES

          ast.rules.each do |rule|
            alternatives_count = rule.alternatives.size

            next unless alternatives_count > max_alternatives

            add_offense(
              rule,
              message: "Rule '#{rule.name}' has #{alternatives_count} alternatives " \
                       "(max: #{max_alternatives}). Consider refactoring."
            )
          end

          @offenses
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::LongRule)
