# frozen_string_literal: true

require_relative "../ast"

module Collie
  module Analyzer
    # Symbol table for tracking declared tokens and nonterminals
    class SymbolTable
      attr_reader :tokens, :nonterminals, :types

      def initialize
        @tokens = {} # name => {type_tag:, location:, usage_count:}
        @nonterminals = {} # name => {location:, usage_count:}
        @types = {} # type_tag => [names]
      end

      def add_token(name, type_tag: nil, location: nil)
        raise Error, "Token '#{name}' already declared at #{@tokens[name][:location]}" if @tokens.key?(name)

        @tokens[name] = { type_tag: type_tag, location: location, usage_count: 0 }
        (@types[type_tag] ||= []) << name if type_tag
      end

      def add_nonterminal(name, location: nil)
        return if @nonterminals.key?(name)

        @nonterminals[name] = { location: location, usage_count: 0 }
      end

      def use_token(name)
        return unless @tokens.key?(name)

        @tokens[name][:usage_count] += 1
      end

      def use_nonterminal(name)
        return unless @nonterminals.key?(name)

        @nonterminals[name][:usage_count] += 1
      end

      def token?(name)
        @tokens.key?(name)
      end

      def nonterminal?(name)
        @nonterminals.key?(name)
      end

      def declared?(name)
        token?(name) || nonterminal?(name)
      end

      def unused_tokens
        @tokens.select { |_name, info| info[:usage_count].zero? }.keys
      end

      def unused_nonterminals
        @nonterminals.select { |_name, info| info[:usage_count].zero? }.keys
      end

      def duplicate_symbols
        @tokens.keys & @nonterminals.keys
      end
    end
  end
end
