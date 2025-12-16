# frozen_string_literal: true

require_relative "../base"

module Collie
  module Linter
    module Rules
      # Checks token naming conventions
      class TokenNaming < Base
        self.rule_name = "TokenNaming"
        self.description = "Tokens should follow UPPER_CASE naming convention"
        self.severity = :convention
        self.autocorrectable = false

        DEFAULT_PATTERN = /^[A-Z][A-Z0-9_]*$/

        def check(ast, _context = {})
          pattern = @config[:pattern] ? Regexp.new(@config[:pattern]) : DEFAULT_PATTERN

          ast.declarations.each do |decl|
            next unless decl.is_a?(AST::TokenDeclaration)

            decl.names.each do |name|
              next if name.match?(pattern)
              next if name.start_with?('"', "'") # Skip literals

              add_offense(decl,
                          message: "Token '#{name}' should match pattern #{pattern.inspect}")
            end
          end

          @offenses
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::TokenNaming)
