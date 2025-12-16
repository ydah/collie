# frozen_string_literal: true

module Collie
  module Linter
    module Rules
      # Detects rules with common prefixes that could be factored
      class FactorizableRules < Base
        self.rule_name = "FactorizableRules"
        self.description = "Suggests factoring rules with common prefixes"
        self.severity = :info
        self.autocorrectable = false

        MIN_PREFIX_LENGTH = 2

        def check(ast, _context = {})
          ast.rules.each do |rule|
            check_rule(rule)
          end

          @offenses
        end

        private

        def check_rule(rule)
          return if rule.alternatives.size < 2

          # Group alternatives by first symbol
          groups = rule.alternatives.group_by { |alt| alt.symbols.first&.name }

          groups.each do |first_symbol, alternatives|
            next if alternatives.size < 2
            next unless first_symbol # Skip epsilon alternatives

            prefix_length = find_common_prefix_length(alternatives)
            next if prefix_length < MIN_PREFIX_LENGTH

            add_offense(
              rule,
              message: "Rule '#{rule.name}' has #{alternatives.size} alternatives with common prefix " \
                       "(#{prefix_length} symbols). Consider factoring."
            )
            break # Only report once per rule
          end
        end

        def find_common_prefix_length(alternatives)
          return 0 if alternatives.empty?

          min_length = alternatives.map { |alt| alt.symbols.size }.min
          prefix_length = 0

          (0...min_length).each do |i|
            symbol_names = alternatives.map { |alt| alt.symbols[i].name }
            break unless symbol_names.uniq.size == 1

            prefix_length += 1
          end

          prefix_length
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::FactorizableRules)
