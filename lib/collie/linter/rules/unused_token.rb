# frozen_string_literal: true

require_relative "../base"

module Collie
  module Linter
    module Rules
      # Detects tokens that are declared but never used
      class UnusedToken < Base
        self.rule_name = "UnusedToken"
        self.description = "Detects tokens that are declared but never used in rules"
        self.severity = :warning
        self.autocorrectable = false

        def check(ast, context = {})
          symbol_table = context[:symbol_table] || build_symbol_table(ast)

          # Track token usage in normal rules
          ast.rules.each do |rule|
            rule.alternatives.each do |alt|
              alt.symbols.each do |symbol|
                symbol_table.use_token(symbol.name) if symbol.terminal?
              end
            end
          end

          # Track token usage in parameterized rules (%rule)
          ast.declarations.each do |decl|
            next unless decl.is_a?(AST::ParameterizedRule)

            decl.alternatives.each do |alt|
              alt.symbols.each do |symbol|
                symbol_table.use_token(symbol.name) if symbol.terminal?
              end
            end
          end

          # Find unused tokens
          symbol_table.unused_tokens.each do |token_name|
            token_info = symbol_table.tokens[token_name]
            add_offense_for_declaration(ast, token_name, token_info[:location])
          end

          @offenses
        end

        private

        def build_symbol_table(ast)
          table = Analyzer::SymbolTable.new

          ast.declarations.each do |decl|
            case decl
            when AST::TokenDeclaration
              decl.names.each do |name|
                table.add_token(name, type_tag: decl.type_tag, location: decl.location)
              rescue Error
                # Ignore duplicates
              end
            end
          end

          table
        end

        def add_offense_for_declaration(ast, token_name, _location)
          # Find the declaration node
          decl = ast.declarations.find do |d|
            d.is_a?(AST::TokenDeclaration) && d.names.include?(token_name)
          end

          return unless decl

          add_offense(decl,
                      message: "Token '#{token_name}' is declared but never used")
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::UnusedToken)
