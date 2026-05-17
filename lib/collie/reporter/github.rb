# frozen_string_literal: true

module Collie
  module Reporter
    # GitHub Actions format reporter
    class Github
      def report(offenses)
        offenses.map { |o| format_offense(o) }.join("\n")
      end

      private

      def format_offense(offense)
        level = github_level(offense.severity)
        file = escape_property(offense.location.file)
        line = offense.location.line
        col = offense.location.column
        message = escape_data(offense.message)

        "::#{level} file=#{file},line=#{line},col=#{col}::#{message}"
      end

      def escape_data(value)
        value.to_s
             .gsub("%", "%25")
             .gsub("\r", "%0D")
             .gsub("\n", "%0A")
      end

      def escape_property(value)
        escape_data(value)
          .gsub(":", "%3A")
          .gsub(",", "%2C")
      end

      def github_level(severity)
        case severity
        when :error
          "error"
        when :warning
          "warning"
        else
          "notice"
        end
      end
    end
  end
end
