# frozen_string_literal: true

require_relative "../base"

module Collie
  module Linter
    module Rules
      # Detects rules that are not reachable from the start symbol
      class UnreachableRule < Base
        self.rule_name = "UnreachableRule"
        self.description = "Detects rules that are not reachable from the start symbol"
        self.severity = :warning
        self.autocorrectable = false

        def check(ast, _context = {})
          return @offenses if ast.rules.empty?

          analyzer = Analyzer::Reachability.new(ast)
          start_symbol = find_start_symbol(ast)
          analyzer.analyze(start_symbol)

          unreachable = analyzer.unreachable_rules

          unreachable.each do |rule_name|
            rule = ast.rules.find { |r| r.name == rule_name }
            next unless rule

            add_offense(rule,
                        message: "Rule '#{rule_name}' is not reachable from start symbol '#{start_symbol}'")
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

Collie::Linter::Registry.register(Collie::Linter::Rules::UnreachableRule)
