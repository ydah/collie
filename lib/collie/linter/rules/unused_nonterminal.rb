# frozen_string_literal: true

require_relative "../base"

module Collie
  module Linter
    module Rules
      # Detects nonterminals that are defined but never referenced
      class UnusedNonterminal < Base
        self.rule_name = "UnusedNonterminal"
        self.description = "Detects nonterminals that are defined but never referenced"
        self.severity = :warning
        self.autocorrectable = false

        def check(ast, _context = {})
          symbol_table = Analyzer::SymbolTable.new

          # Register all nonterminals
          ast.rules.each do |rule|
            symbol_table.add_nonterminal(rule.name, location: rule.location)
          end

          # Find start symbol
          start_symbol = find_start_symbol(ast)

          # Track nonterminal usage in normal rules
          ast.rules.each do |rule|
            rule.alternatives.each do |alt|
              alt.symbols.each do |symbol|
                if symbol.nonterminal?
                  symbol_table.use_nonterminal(symbol.name)
                  # Also consider parameterized rule call arguments: list(expr)
                  if symbol.arguments
                    symbol.arguments.each do |arg|
                      symbol_table.use_nonterminal(arg.name) if arg.nonterminal?
                    end
                  end
                end
              end
            end
          end

          # Track nonterminal usage in parameterized rules (%rule)
          ast.declarations.each do |decl|
            next unless decl.is_a?(AST::ParameterizedRule)

            decl.alternatives.each do |alt|
              alt.symbols.each do |symbol|
                if symbol.nonterminal?
                  symbol_table.use_nonterminal(symbol.name)
                  if symbol.arguments
                    symbol.arguments.each do |arg|
                      symbol_table.use_nonterminal(arg.name) if arg.nonterminal?
                    end
                  end
                end
              end
            end
          end

          # Mark start symbol as used
          symbol_table.use_nonterminal(start_symbol) if start_symbol

          # Find unused nonterminals
          symbol_table.unused_nonterminals.each do |nonterminal_name|
            # Skip start symbol
            next if nonterminal_name == start_symbol

            rule = ast.rules.find { |r| r.name == nonterminal_name }
            next unless rule

            add_offense(rule,
                        message: "Nonterminal '#{nonterminal_name}' is defined but never used")
          end

          @offenses
        end

        private

        def find_start_symbol(ast)
          start_decl = ast.declarations.find { |d| d.is_a?(AST::StartDeclaration) }
          return start_decl.symbol if start_decl

          # Default to first rule
          ast.rules.first&.name
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::UnusedNonterminal)
