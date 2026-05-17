# frozen_string_literal: true

require_relative "../base"

module Collie
  module Linter
    module Rules
      # Detects references to undeclared tokens or nonterminals
      class UndefinedSymbol < Base
        self.rule_name = "UndefinedSymbol"
        self.description = "Detects references to undeclared tokens or nonterminals"
        self.severity = :error
        self.autocorrectable = false

        def check(ast, context = {})
          symbol_table = context[:symbol_table] || build_symbol_table(ast)

          ast.rules.each do |rule|
            rule.alternatives.each do |alt|
              alt.symbols.each { |symbol| check_symbol(symbol_table, symbol) }
            end
          end

          check_declarations(ast, symbol_table)

          @offenses
        end

        private

        def check_declarations(ast, symbol_table)
          ast.declarations.each do |decl|
            case decl
            when AST::StartDeclaration
              next if symbol_table.nonterminal?(decl.symbol)

              add_offense(decl, message: "Undefined start symbol '#{decl.symbol}'")
            when AST::TypeDeclaration
              decl.names.each do |name|
                next if symbol_table.declared?(name)

                add_offense(decl, message: "%type references undefined symbol '#{name}'")
              end
            end
          end
        end

        def check_symbol(symbol_table, symbol)
          unless symbol_table.declared?(symbol.name)
            add_offense(symbol,
                        message: "Undefined symbol '#{symbol.name}'")
          end

          symbol.arguments&.each { |argument| check_symbol(symbol_table, argument) }
        end

        def build_symbol_table(ast)
          table = Analyzer::SymbolTable.new

          ast.declarations.each do |decl|
            case decl
            when AST::TokenDeclaration
              decl.names.each { |name| table.add_token(name, type_tag: decl.type_tag, location: decl.location) }
            when AST::ParameterizedRule
              table.add_nonterminal(decl.name, location: decl.location)
            when AST::InlineRule
              table.add_nonterminal(decl.rule, location: decl.location)
            end
          end

          ast.rules.each do |rule|
            table.add_nonterminal(rule.name, location: rule.location)
          end

          table
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::UndefinedSymbol)
