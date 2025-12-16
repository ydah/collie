# frozen_string_literal: true

module Collie
  module Linter
    module Rules
      # Detects missing %start declaration when it's ambiguous
      class MissingStartSymbol < Base
        self.rule_name = "MissingStartSymbol"
        self.description = "Detects missing %start declaration with ambiguous default"
        self.severity = :error
        self.autocorrectable = false

        def check(ast, _context = {})
          has_start = ast.declarations.any? { |decl| decl.is_a?(AST::StartDeclaration) }

          # If %start is declared, no problem
          return @offenses if has_start

          # If no rules defined, it's ambiguous
          if ast.rules.empty?
            # Create a pseudo-location since we don't have a specific node
            location = AST::Location.new(file: "grammar", line: 1, column: 1)
            offense = Offense.new(
              rule: self.class,
              location: location,
              message: "No %start declaration and no rules defined"
            )
            @offenses << offense
          end

          @offenses
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::MissingStartSymbol)
