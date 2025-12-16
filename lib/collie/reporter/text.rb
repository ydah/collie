# frozen_string_literal: true

begin
  require "pastel"
  PASTEL_AVAILABLE = true
rescue LoadError
  PASTEL_AVAILABLE = false
end

module Collie
  module Reporter
    # Text reporter for terminal output
    class Text
      def initialize(colorize: true)
        @colorize = colorize && PASTEL_AVAILABLE
        @pastel = PASTEL_AVAILABLE ? Pastel.new(enabled: @colorize) : nil
      end

      def report(offenses)
        return success_message if offenses.empty?

        grouped = offenses.group_by { |o| o.location.file }
        output = []

        grouped.each do |file, file_offenses|
          output << ""
          output << (@pastel ? @pastel.bold(file) : file)

          file_offenses.sort_by { |o| [o.location.line, o.location.column] }.each do |offense|
            output << format_offense(offense)
          end
        end

        output << ""
        output << summary(offenses)
        output.join("\n")
      end

      private

      def format_offense(offense)
        location = "#{offense.location.line}:#{offense.location.column}"
        severity = colorize_severity(offense.severity)
        rule = offense.rule.rule_name

        "  #{location}: #{severity}: [#{rule}] #{offense.message}"
      end

      def colorize_severity(severity)
        text = severity.to_s
        return text unless @pastel

        case severity
        when :error
          @pastel.red.bold(text)
        when :warning
          @pastel.yellow.bold(text)
        when :convention
          @pastel.blue(text)
        when :info
          @pastel.cyan(text)
        else
          text
        end
      end

      def success_message
        msg = "✓ No offenses detected"
        @pastel ? @pastel.green(msg) : msg
      end

      def summary(offenses)
        counts = offenses.group_by(&:severity).transform_values(&:count)
        parts = []

        if counts[:error]
          msg = "#{counts[:error]} error(s)"
          parts << (@pastel ? @pastel.red(msg) : msg)
        end
        if counts[:warning]
          msg = "#{counts[:warning]} warning(s)"
          parts << (@pastel ? @pastel.yellow(msg) : msg)
        end
        if counts[:convention]
          msg = "#{counts[:convention]} convention(s)"
          parts << (@pastel ? @pastel.blue(msg) : msg)
        end
        if counts[:info]
          msg = "#{counts[:info]} info"
          parts << (@pastel ? @pastel.cyan(msg) : msg)
        end

        "#{parts.join(', ')} found"
      end
    end
  end
end
