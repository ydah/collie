# frozen_string_literal: true

require "json"

module Collie
  module Reporter
    # JSON reporter
    class Json
      def report(offenses)
        output = {
          summary: {
            total: offenses.length,
            by_severity: count_by_severity(offenses)
          },
          files: group_by_file(offenses)
        }

        JSON.pretty_generate(output)
      end

      private

      def count_by_severity(offenses)
        offenses.group_by(&:severity).transform_values(&:count)
      end

      def group_by_file(offenses)
        grouped = offenses.group_by { |o| o.location.file }

        grouped.map do |file, file_offenses|
          {
            path: file,
            offenses: file_offenses.map { |o| format_offense(o) }
          }
        end
      end

      def format_offense(offense)
        {
          rule: offense.rule.rule_name,
          severity: offense.severity,
          message: offense.message,
          location: {
            line: offense.location.line,
            column: offense.location.column,
            length: offense.location.length
          }
        }
      end
    end
  end
end
