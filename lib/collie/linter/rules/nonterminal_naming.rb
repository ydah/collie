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
          pattern_config = config_value(:pattern)
          pattern = pattern_config ? Regexp.new(pattern_config) : DEFAULT_PATTERN

          each_rule_like(ast) do |rule|
            name = rule_like_name(rule)
            next if name.match?(pattern)

            add_offense(rule,
                        message: "Nonterminal '#{name}' should match pattern #{pattern.inspect}")
          end

          @offenses
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::NonterminalNaming)
