# frozen_string_literal: true

require "json"

module Collie
  module Reporter
    # SARIF 2.1.0 reporter for code scanning integrations.
    class Sarif
      def report(offenses)
        JSON.pretty_generate(
          version: "2.1.0",
          "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
          runs: [
            {
              tool: {
                driver: {
                  name: "Collie",
                  informationUri: "https://github.com/ydah/collie",
                  rules: rules(offenses)
                }
              },
              results: offenses.map { |offense| result(offense) }
            }
          ]
        )
      end

      private

      def rules(offenses)
        offenses.map(&:rule).uniq(&:rule_name).map do |rule|
          {
            id: rule.rule_name,
            name: rule.rule_name,
            shortDescription: {
              text: rule.description
            },
            defaultConfiguration: {
              level: level(rule.severity)
            }
          }
        end
      end

      def result(offense)
        {
          ruleId: offense.rule.rule_name,
          level: level(offense.severity),
          message: {
            text: offense.message
          },
          locations: [
            {
              physicalLocation: {
                artifactLocation: {
                  uri: offense.location.file
                },
                region: {
                  startLine: offense.location.line,
                  startColumn: offense.location.column,
                  charLength: offense.location.length
                }
              }
            }
          ]
        }
      end

      def level(severity)
        case severity
        when :error
          "error"
        when :warning, :convention
          "warning"
        else
          "note"
        end
      end
    end
  end
end
