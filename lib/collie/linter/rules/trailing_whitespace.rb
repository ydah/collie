# frozen_string_literal: true

module Collie
  module Linter
    module Rules
      # Detects trailing whitespace in source code
      class TrailingWhitespace < Base
        self.rule_name = "TrailingWhitespace"
        self.description = "Detects trailing whitespace at the end of lines"
        self.severity = :convention
        self.autocorrectable = true

        # Simple node class for holding location
        Node = Struct.new(:location)

        def check(_ast, context = {})
          source = context[:source]
          return @offenses unless source

          source.lines.each_with_index do |line, index|
            line_number = index + 1
            next unless line.match?(/[ \t]+\n$|[ \t]+$/)

            location = AST::Location.new(
              file: context[:file] || "grammar",
              line: line_number,
              column: line.rstrip.length + 1
            )

            add_offense(
              Node.new(location),
              message: "Trailing whitespace detected",
              autocorrect: lambda {
                context[:source] = source.gsub(/[ \t]+\n/, "\n").gsub(/[ \t]+$/, "")
              }
            )
          end

          @offenses
        end
      end
    end
  end
end

Collie::Linter::Registry.register(Collie::Linter::Rules::TrailingWhitespace)
