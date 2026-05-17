# frozen_string_literal: true

require_relative "../base"

module Collie
  module Linter
    module Rules
      # Detects conflicting grammar symbol declarations.
      class SymbolConflict < Base
        self.rule_name = "SymbolConflict"
        self.description = "Detects conflicting token and nonterminal declarations"
        self.severity = :error
        self.autocorrectable = false

        def check(ast, _context = {})
          tokens = collect_tokens(ast)
          nonterminals = collect_nonterminals(ast)

          report_token_nonterminal_conflicts(tokens, nonterminals)
          report_duplicate_nonterminals(nonterminals)

          @offenses
        end

        private

        Entry = Struct.new(:name, :location)

        def collect_tokens(ast)
          ast.declarations.each_with_object({}) do |decl, tokens|
            next unless decl.is_a?(AST::TokenDeclaration)

            decl.names.each do |name|
              tokens[name] ||= Entry.new(name, decl.location)
            end
          end
        end

        def collect_nonterminals(ast)
          entries = []

          ast.declarations.each do |decl|
            case decl
            when AST::ParameterizedRule
              entries << Entry.new(decl.name, decl.location)
            when AST::InlineRule
              entries << Entry.new(decl.rule, decl.location)
            end
          end

          ast.rules.each do |rule|
            entries << Entry.new(rule.name, rule.location)
          end

          entries
        end

        def report_token_nonterminal_conflicts(tokens, nonterminals)
          nonterminals.each do |entry|
            next unless tokens.key?(entry.name)

            add_offense(
              Node.new(entry.location),
              message: "Symbol '#{entry.name}' is declared as both token and nonterminal"
            )
          end
        end

        def report_duplicate_nonterminals(nonterminals)
          seen = {}

          nonterminals.each do |entry|
            if seen.key?(entry.name)
              add_offense(
                Node.new(entry.location),
                message: "Nonterminal '#{entry.name}' already defined at #{seen[entry.name]}"
              )
            else
              seen[entry.name] = entry.location
            end
          end
        end

        Node = Struct.new(:location)
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::SymbolConflict)
