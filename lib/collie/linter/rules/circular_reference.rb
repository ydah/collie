# frozen_string_literal: true

require "set"

module Collie
  module Linter
    module Rules
      # Detects circular references that lead to infinite recursion
      class CircularReference < Base
        self.rule_name = "CircularReference"
        self.description = "Detects infinite recursion in grammar rules"
        self.severity = :error
        self.autocorrectable = false

        def check(ast, _context = {})
          @rules_map = build_rules_map(ast)
          @dependencies = build_dependency_graph
          productive_rules = compute_productive_rules

          strongly_connected_components.each do |component|
            next unless cyclic_component?(component)
            next if component.any? { |rule_name| productive_rules.include?(rule_name) }

            component.each do |rule_name|
              rule = @rules_map[rule_name]
              add_offense(rule, message: "Rule '#{rule_name}' is part of a non-productive circular reference") if rule
            end
          end

          @offenses
        end

        private

        def build_rules_map(ast)
          rules = ast.rules + ast.declarations.select do |decl|
            decl.is_a?(AST::ParameterizedRule) || decl.is_a?(AST::InlineRule)
          end

          rules.each_with_object({}) do |rule, map|
            map[rule_name(rule)] = rule
          end
        end

        def rule_name(rule)
          rule.is_a?(AST::InlineRule) ? rule.rule : rule.name
        end

        def build_dependency_graph
          @rules_map.transform_values do |rule|
            rule.alternatives.each_with_object(Set.new) do |alternative, dependencies|
              alternative.symbols.each { |symbol| collect_dependencies(symbol, dependencies) }
            end
          end
        end

        def collect_dependencies(symbol, dependencies)
          dependencies << symbol.name if symbol.nonterminal? && @rules_map.key?(symbol.name)
          symbol.arguments&.each { |argument| collect_dependencies(argument, dependencies) }
        end

        def compute_productive_rules
          productive = Set.new

          loop do
            changed = false

            @rules_map.each do |name, rule|
              next if productive.include?(name)
              next unless rule.alternatives.any? { |alternative| productive_alternative?(alternative, productive) }

              productive << name
              changed = true
            end

            break unless changed
          end

          productive
        end

        def productive_alternative?(alternative, productive_rules)
          return true if alternative.explicit_empty || alternative.symbols.empty?

          alternative.symbols.all? do |symbol|
            productive_symbol?(symbol, productive_rules)
          end
        end

        def productive_symbol?(symbol, productive_rules)
          return true if symbol.terminal?

          symbol.nonterminal? && productive_rules.include?(symbol.name)
        end

        def strongly_connected_components
          @index = 0
          @indices = {}
          @lowlinks = {}
          @stack = []
          @on_stack = Set.new
          components = []

          @rules_map.each_key do |rule_name|
            strong_connect(rule_name, components) unless @indices.key?(rule_name)
          end

          components
        end

        def strong_connect(rule_name, components)
          @indices[rule_name] = @index
          @lowlinks[rule_name] = @index
          @index += 1
          @stack << rule_name
          @on_stack << rule_name

          @dependencies[rule_name].each do |dependency|
            if !@indices.key?(dependency)
              strong_connect(dependency, components)
              @lowlinks[rule_name] = [@lowlinks[rule_name], @lowlinks[dependency]].min
            elsif @on_stack.include?(dependency)
              @lowlinks[rule_name] = [@lowlinks[rule_name], @indices[dependency]].min
            end
          end

          return unless @lowlinks[rule_name] == @indices[rule_name]

          component = []
          loop do
            dependency = @stack.pop
            @on_stack.delete(dependency)
            component << dependency
            break if dependency == rule_name
          end
          components << component
        end

        def cyclic_component?(component)
          component.size > 1 || @dependencies[component.first].include?(component.first)
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::CircularReference)
