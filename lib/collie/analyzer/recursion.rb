# frozen_string_literal: true

require_relative "../ast"

module Collie
  module Analyzer
    # Recursion analysis for grammar rules
    class Recursion
      def initialize(grammar)
        @grammar = grammar
        @left_recursive = []
        @right_recursive = []
      end

      def analyze
        @grammar.rules.each do |rule|
          check_left_recursion(rule)
          check_right_recursion(rule)
        end

        {
          left_recursive: @left_recursive,
          right_recursive: @right_recursive
        }
      end

      def left_recursive?(rule_name)
        @left_recursive.include?(rule_name)
      end

      def right_recursive?(rule_name)
        @right_recursive.include?(rule_name)
      end

      private

      def check_left_recursion(rule)
        rule.alternatives.each do |alt|
          next if alt.symbols.empty?

          first_symbol = alt.symbols.first
          if first_symbol.nonterminal? && first_symbol.name == rule.name && !@left_recursive.include?(rule.name)
            @left_recursive << rule.name
          end
        end

        # Check for indirect left recursion
        check_indirect_left_recursion(rule)
      end

      def check_right_recursion(rule)
        rule.alternatives.each do |alt|
          next if alt.symbols.empty?

          last_symbol = alt.symbols.last
          if last_symbol.nonterminal? && last_symbol.name == rule.name && !@right_recursive.include?(rule.name)
            @right_recursive << rule.name
          end
        end
      end

      def check_indirect_left_recursion(rule, visited = Set.new)
        return if visited.include?(rule.name)

        visited << rule.name

        rule.alternatives.each do |alt|
          check_alternative_for_indirect_recursion(alt, rule.name)
        end
      end

      def check_alternative_for_indirect_recursion(alt, rule_name)
        return if alt.symbols.empty?

        first_symbol = alt.symbols.first
        return unless first_symbol.nonterminal?

        dependent_rule = @grammar.rules.find { |r| r.name == first_symbol.name }
        return unless dependent_rule

        check_dependent_rule_for_recursion(dependent_rule, rule_name)
      end

      def check_dependent_rule_for_recursion(dependent_rule, rule_name)
        dependent_rule.alternatives.each do |dep_alt|
          next if dep_alt.symbols.empty?
          next unless dep_alt.symbols.first.nonterminal?
          next unless dep_alt.symbols.first.name == rule_name
          next if @left_recursive.include?(rule_name)

          @left_recursive << rule_name
        end
      end
    end
  end
end
