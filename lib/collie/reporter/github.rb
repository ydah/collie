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
        file = offense.location.file
        line = offense.location.line
        col = offense.location.column
        message = offense.message.gsub(",", "%2C") # Escape commas

        "::#{level} file=#{file},line=#{line},col=#{col}::#{message}"
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
