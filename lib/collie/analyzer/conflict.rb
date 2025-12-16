# frozen_string_literal: true

require_relative "../ast"

module Collie
  module Analyzer
    # Conflict detection helpers for grammar analysis
    class Conflict
      def initialize(grammar, symbol_table)
        @grammar = grammar
        @symbol_table = symbol_table
        @precedence_map = {}
      end

      def analyze
        build_precedence_map
        {
          potential_shift_reduce: detect_shift_reduce_conflicts,
          potential_reduce_reduce: detect_reduce_reduce_conflicts,
          ambiguous_precedence: detect_ambiguous_precedence
        }
      end

      private

      def build_precedence_map
        precedence_level = 0
        @grammar.declarations.each do |decl|
          next unless decl.is_a?(AST::PrecedenceDeclaration)

          precedence_level += 1
          decl.tokens.each do |token|
            @precedence_map[token] = {
              level: precedence_level,
              associativity: decl.associativity
            }
          end
        end
      end

      def detect_shift_reduce_conflicts
        conflicts = []

        @grammar.rules.each do |rule|
          rule.alternatives.each_with_index do |alt, alt_idx|
            alt.symbols.each_with_index do |symbol, sym_idx|
              next unless symbol.terminal?
              next if sym_idx == alt.symbols.length - 1

              # Check if this could cause a shift-reduce conflict
              next_symbol = alt.symbols[sym_idx + 1]
              next unless next_symbol.nonterminal? && !has_precedence?(symbol.name)

              conflicts << {
                rule: rule.name,
                alternative: alt_idx,
                symbol: symbol.name,
                location: symbol.location
              }
            end
          end
        end

        conflicts
      end

      def detect_reduce_reduce_conflicts
        conflicts = []
        rule_groups = @grammar.rules.group_by { |r| r.alternatives.map { |a| a.symbols.map(&:name) } }

        rule_groups.each_value do |rules|
          next if rules.length <= 1

          conflicts << {
            rules: rules.map(&:name),
            location: rules.first.location
          }
        end

        conflicts
      end

      def detect_ambiguous_precedence
        ambiguous = []

        @grammar.rules.each do |rule|
          rule.alternatives.each do |alt|
            operators = alt.symbols.select { |s| s.terminal? && operator?(s.name) }
            next if operators.empty?

            operators_without_prec = operators.reject { |op| has_precedence?(op.name) }
            next if operators_without_prec.empty?

            ambiguous << {
              rule: rule.name,
              operators: operators_without_prec.map(&:name),
              location: rule.location
            }
          end
        end

        ambiguous
      end

      def has_precedence?(token)
        @precedence_map.key?(token)
      end

      def operator?(token)
        token.match?(%r{^[+\-*/%^<>=!&|]+$})
      end
    end
  end
end
