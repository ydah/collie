# frozen_string_literal: true

module Collie
  module Linter
    module Rules
      # Detects inconsistent type tag naming
      class ConsistentTagNaming < Base
        self.rule_name = "ConsistentTagNaming"
        self.description = "Ensures consistent naming style for type tags"
        self.severity = :convention
        self.autocorrectable = false

        def check(ast, _context = {})
          tags = collect_type_tags(ast)
          return @offenses if tags.size < 2

          styles = tags.group_by { |tag, _| detect_style(tag) }

          # If we have multiple styles, report inconsistency
          add_inconsistency_offenses(styles) if styles.size > 1

          @offenses
        end

        private

        def collect_type_tags(ast)
          tags = []

          ast.declarations.each do |decl|
            if (decl.is_a?(AST::TokenDeclaration) || decl.is_a?(AST::TypeDeclaration)) && decl.type_tag
              tags << [decl.type_tag, decl.location]
            end
          end

          tags
        end

        def detect_style(tag)
          return :snake_case if tag.match?(/^[a-z][a-z0-9_]*$/)
          return :camel_case if tag.match?(/^[a-z][a-zA-Z0-9]*$/)
          return :pascal_case if tag.match?(/^[A-Z][a-zA-Z0-9]*$/)
          return :upper_snake_case if tag.match?(/^[A-Z][A-Z0-9_]*$/)

          :other
        end

        Node = Struct.new(:location)

        def add_inconsistency_offenses(styles)
          style_names = styles.keys.map(&:to_s).join(", ")
          most_common_style = styles.max_by { |_, tags| tags.size }[0]
          expected_tags = styles.fetch(most_common_style)
          outliers = styles.reject { |style, _| style == most_common_style }.values.flatten(1)

          outliers.each do |tag, location|
            add_offense(
              Node.new(location || expected_tags.first[1] || AST::Location.new(file: "grammar", line: 1, column: 1)),
              message: "Type tag '#{tag}' uses a different naming style (#{style_names}). " \
                       "Consider using #{most_common_style} throughout."
            )
          end
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::ConsistentTagNaming)
