# frozen_string_literal: true

module Collie
  module Linter
    module Rules
      # Detects empty action blocks
      class EmptyAction < Base
        self.rule_name = "EmptyAction"
        self.description = "Detects empty action blocks { }"
        self.severity = :convention
        self.autocorrectable = true

        def check(ast, _context = {})
          ast.rules.each do |rule|
            check_rule(rule)
          end

          @offenses
        end

        private

        def check_rule(rule)
          rule.alternatives.each do |alt|
            next unless alt.action
            next unless empty_action?(alt.action)

            add_offense(
              alt,
              message: "Empty action block can be removed",
              autocorrect: -> { remove_action(alt) }
            )
          end
        end

        def empty_action?(action)
          # Check if action code is empty or contains only whitespace
          return true unless action.code
          return true if action.code.strip.empty?

          false
        end

        def remove_action(alternative)
          alternative.action = nil
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::EmptyAction)
