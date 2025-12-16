# frozen_string_literal: true

require_relative "../base"

module Collie
  module Linter
    module Rules
      # Detects tokens defined multiple times
      class DuplicateToken < Base
        self.rule_name = "DuplicateToken"
        self.description = "Detects tokens defined multiple times"
        self.severity = :error
        self.autocorrectable = false

        def check(ast, _context = {})
          seen = {}

          ast.declarations.each do |decl|
            next unless decl.is_a?(AST::TokenDeclaration)

            decl.names.each do |name|
              if seen[name]
                add_offense(decl,
                            message: "Token '#{name}' already defined at #{seen[name]}")
              else
                seen[name] = decl.location
              end
            end
          end

          @offenses
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::DuplicateToken)
