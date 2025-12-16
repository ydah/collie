# frozen_string_literal: true

require_relative "../base"

module Collie
  module Linter
    module Rules
      # Checks nonterminal naming conventions
      class NonterminalNaming < Base
        self.rule_name = "NonterminalNaming"
        self.description = "Nonterminals should follow snake_case naming convention"
        self.severity = :convention
        self.autocorrectable = false

        DEFAULT_PATTERN = /^[a-z][a-z0-9_]*$/

        def check(ast, _context = {})
          pattern = @config[:pattern] ? Regexp.new(@config[:pattern]) : DEFAULT_PATTERN

          ast.rules.each do |rule|
            next if rule.name.match?(pattern)

            add_offense(rule,
                        message: "Nonterminal '#{rule.name}' should match pattern #{pattern.inspect}")
          end

          @offenses
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::NonterminalNaming)
