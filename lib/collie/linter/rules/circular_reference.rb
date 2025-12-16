# frozen_string_literal: true

module Collie
  module Linter
    module Rules
      # Detects circular references that lead to infinite recursion
      class CircularReference < Base
        self.rule_name = "CircularReference"
        self.description = "Detects infinite recursion in grammar rules"
        self.severity = :error
        self.autocorrectable = false

        def check(ast, _context = {})
          @rules_map = build_rules_map(ast)
          @visited = Set.new
          @rec_stack = Set.new

          ast.rules.each do |rule|
            next if @visited.include?(rule.name)

            if has_cycle?(rule.name, [])
              add_offense(rule, message: "Rule '#{rule.name}' is part of a circular reference")
            end
          end

          @offenses
        end

        private

        def build_rules_map(ast)
          ast.rules.each_with_object({}) do |rule, map|
            map[rule.name] = rule
          end
        end

        def has_cycle?(rule_name, path)
          return false if @visited.include?(rule_name)

          if @rec_stack.include?(rule_name)
            # Found a cycle - check if it's truly circular (no terminals in alternatives)
            return true if pure_nonterminal_cycle?(rule_name)

            return false
          end

          @rec_stack.add(rule_name)
          current_path = path + [rule_name]

          rule = @rules_map[rule_name]
          # Check each alternative - only follow nonterminals
          rule&.alternatives&.each do |alt|
            # Skip alternatives with terminals or empty alternatives
            next if has_terminal_or_empty?(alt)

            # Only check the first symbol for cycles
            first_symbol = alt.symbols.first
            next unless first_symbol&.nonterminal?

            return true if has_cycle?(first_symbol.name, current_path)
          end

          @rec_stack.delete(rule_name)
          @visited.add(rule_name)

          false
        end

        def has_terminal_or_empty?(alternative)
          return true if alternative.symbols.empty?

          alternative.symbols.any?(&:terminal?)
        end

        def pure_nonterminal_cycle?(rule_name)
          rule = @rules_map[rule_name]
          return false unless rule

          # Check if all alternatives contain only nonterminals
          rule.alternatives.all? do |alt|
            !has_terminal_or_empty?(alt)
          end
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::CircularReference)
