# frozen_string_literal: true

require "set"

require_relative "../ast"

module Collie
  module Analyzer
    # Reachability analysis for grammar rules
    class Reachability
      def initialize(grammar)
        @grammar = grammar
        @reachable = Set.new
        @dependencies = Hash.new { |h, k| h[k] = Set.new }
      end

      def analyze(start_symbol = nil)
        build_dependency_graph
        start = start_symbol || infer_start_symbol
        mark_reachable(start) if start
        @reachable
      end

      def unreachable_rules
        all_rules = @grammar.rules.to_set(&:name)
        all_rules - @reachable
      end

      private

      def build_dependency_graph
        rule_like_nodes.each do |rule|
          current_rule_name = rule_name(rule)

          rule.alternatives.each do |alt|
            alt.symbols.each do |symbol|
              if symbol.nonterminal?
                @dependencies[current_rule_name] << symbol.name
                # Also consider parameterized rule call arguments: list(expr)
                if symbol.arguments
                  symbol.arguments.each do |arg|
                    @dependencies[current_rule_name] << arg.name if arg.nonterminal?
                  end
                end
              end
            end
          end
        end
      end

      def rule_like_nodes
        @grammar.rules + @grammar.declarations.select { |declaration| rule_like_declaration?(declaration) }
      end

      def rule_like_declaration?(declaration)
        declaration.is_a?(AST::ParameterizedRule) || declaration.is_a?(AST::InlineRule)
      end

      def rule_name(rule)
        rule.is_a?(AST::InlineRule) ? rule.rule : rule.name
      end

      def infer_start_symbol
        # Find start symbol from %start declaration
        start_decl = @grammar.declarations.find { |d| d.is_a?(AST::StartDeclaration) }
        return start_decl.symbol if start_decl

        # Otherwise, use the first rule
        @grammar.rules.first&.name
      end

      def mark_reachable(symbol)
        return if @reachable.include?(symbol)

        @reachable << symbol
        @dependencies[symbol].each { |dep| mark_reachable(dep) }
      end
    end
  end
end
