# frozen_string_literal: true

module Collie
  module Linter
    module Rules
      # Detects empty action blocks
      class EmptyAction < Base
        self.rule_name = "EmptyAction"
        self.description = "Detects empty action blocks { }"
        self.severity = :convention
        self.autocorrectable = true

        def check(ast, context = {})
          ast.rules.each do |rule|
            check_rule(rule, context)
          end

          @offenses
        end

        private

        def check_rule(rule, context)
          rule.alternatives.each do |alt|
            next unless alt.action
            next unless empty_action?(alt.action)

            add_offense(
              alt.action,
              message: "Empty action block can be removed",
              autocorrect: -> { remove_action(alt, context) }
            )
          end
        end

        def empty_action?(action)
          code = action.code.to_s.strip
          return true if code.empty?

          action_body = if code.start_with?("{") && code.end_with?("}")
                          code[1...-1].strip
                        else
                          code
                        end

          action_body.empty?
        end

        def remove_action(alternative, context)
          action = alternative.action
          if context[:source] && action&.location
            context[:source] = remove_action_from_source(context[:source], action.location)
          end

          alternative.action = nil
        end

        def remove_action_from_source(source, location)
          index = source_index(source, location)
          return source unless index

          prefix = source[0...index].sub(/[ \t]*\z/, "")
          suffix = source[(index + location.length)..] || ""
          "#{prefix}#{suffix}"
        end

        def source_index(source, location)
          offset = 0

          source.each_line.with_index(1) do |line, line_number|
            return offset + location.column - 1 if line_number == location.line

            offset += line.length
          end

          nil
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::EmptyAction)
