# frozen_string_literal: true

require "set"

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
        rule_like_nodes.each do |rule|
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

      def rule_like_nodes
        @grammar.rules + @grammar.declarations.select { |declaration| rule_like_declaration?(declaration) }
      end

      def rule_like_declaration?(declaration)
        declaration.is_a?(AST::ParameterizedRule) || declaration.is_a?(AST::InlineRule)
      end

      def rule_name(rule)
        rule.is_a?(AST::InlineRule) ? rule.rule : rule.name
      end

      def check_left_recursion(rule)
        name = rule_name(rule)

        rule.alternatives.each do |alt|
          next if alt.symbols.empty?

          first_symbol = alt.symbols.first
          if first_symbol.nonterminal? && first_symbol.name == name && !@left_recursive.include?(name)
            @left_recursive << name
          end
        end

        # Check for indirect left recursion
        check_indirect_left_recursion(rule)
      end

      def check_right_recursion(rule)
        name = rule_name(rule)

        rule.alternatives.each do |alt|
          next if alt.symbols.empty?

          last_symbol = alt.symbols.last
          if last_symbol.nonterminal? && last_symbol.name == name && !@right_recursive.include?(name)
            @right_recursive << name
          end
        end
      end

      def check_indirect_left_recursion(rule, visited = Set.new)
        name = rule_name(rule)
        return if visited.include?(name)

        visited << name

        rule.alternatives.each do |alt|
          check_alternative_for_indirect_recursion(alt, name)
        end
      end

      def check_alternative_for_indirect_recursion(alt, rule_name)
        return if alt.symbols.empty?

        first_symbol = alt.symbols.first
        return unless first_symbol.nonterminal?

        dependent_rule = rule_like_nodes.find { |candidate| rule_name(candidate) == first_symbol.name }
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
