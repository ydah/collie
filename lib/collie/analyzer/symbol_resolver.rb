# frozen_string_literal: true

require_relative "../ast"

module Collie
  module Analyzer
    # Resolves symbol kinds using declared tokens and nonterminals.
    class SymbolResolver
      def self.resolve(grammar, symbol_table)
        new(grammar, symbol_table).resolve
      end

      def initialize(grammar, symbol_table)
        @grammar = grammar
        @symbol_table = symbol_table
      end

      def resolve
        each_alternative do |alternative|
          alternative.symbols.each { |symbol| resolve_symbol(symbol) }
        end

        @grammar
      end

      private

      def each_alternative
        @grammar.rules.each do |rule|
          rule.alternatives.each { |alternative| yield alternative }
        end

        @grammar.declarations.each do |declaration|
          next unless declaration.is_a?(AST::ParameterizedRule) || declaration.is_a?(AST::InlineRule)

          declaration.alternatives.each { |alternative| yield alternative }
        end
      end

      def resolve_symbol(symbol)
        if @symbol_table.token?(symbol.name)
          symbol.kind = :terminal
        elsif @symbol_table.nonterminal?(symbol.name)
          symbol.kind = :nonterminal
        end

        symbol.arguments&.each { |argument| resolve_symbol(argument) }
      end
    end
  end
end
