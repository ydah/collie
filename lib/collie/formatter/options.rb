# frozen_string_literal: true

module Collie
  module Formatter
    # Formatting options
    class Options
      attr_accessor :indent_size, :align_tokens, :align_alternatives,
                    :blank_lines_around_sections, :max_line_length

      def initialize(config = {})
        @indent_size = config[:indent_size] || 2
        @align_tokens = config[:align_tokens] != false
        @align_alternatives = config[:align_alternatives] != false
        @blank_lines_around_sections = config[:blank_lines_around_sections] || 1
        @max_line_length = config[:max_line_length] || 120
      end

      def indent(level = 1)
        " " * (indent_size * level)
      end
    end
  end
end
