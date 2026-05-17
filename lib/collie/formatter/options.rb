# frozen_string_literal: true

module Collie
  module Formatter
    # Formatting options
    class Options
      attr_accessor :indent_size, :align_tokens, :align_alternatives,
                    :blank_lines_around_sections, :max_line_length

      def initialize(config = {})
        @indent_size = fetch_option(config, :indent_size, 2)
        @align_tokens = fetch_option(config, :align_tokens, true)
        @align_alternatives = fetch_option(config, :align_alternatives, true)
        @blank_lines_around_sections = fetch_option(config, :blank_lines_around_sections, 1)
        @max_line_length = fetch_option(config, :max_line_length, 120)
      end

      def indent(level = 1)
        " " * (indent_size * level)
      end

      private

      def fetch_option(config, key, default)
        return default unless config

        string_key = key.to_s
        return config[string_key] if config.key?(string_key)
        return config[key] if config.key?(key)

        default
      end
    end
  end
end
