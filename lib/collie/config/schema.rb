# frozen_string_literal: true

module Collie
  class Config
    # JSON Schema for .collie.yml files.
    module Schema
      SEVERITIES = %w[error warning convention info].freeze

      SEVERITY_SCHEMA = {
        "type" => "string",
        "enum" => SEVERITIES
      }.freeze

      FORMATTER_PROPERTIES = {
        "indent_size" => {
          "type" => "integer",
          "minimum" => 1
        },
        "align_tokens" => {
          "type" => "boolean"
        },
        "align_alternatives" => {
          "type" => "boolean"
        },
        "blank_lines_around_sections" => {
          "type" => "integer",
          "minimum" => 0
        },
        "max_line_length" => {
          "type" => "integer",
          "minimum" => 1
        }
      }.freeze

      class << self
        def to_h
          {
            "$schema" => "https://json-schema.org/draft/2020-12/schema",
            "title" => "Collie configuration",
            "type" => "object",
            "additionalProperties" => false,
            "properties" => properties,
            "$defs" => definitions
          }
        end

        private

        def properties
          {
            "inherit_from" => {
              "type" => "string"
            },
            "include" => string_array_schema,
            "exclude" => string_array_schema,
            "formatter" => formatter_schema,
            "rules" => rules_schema
          }
        end

        def formatter_schema
          {
            "type" => "object",
            "additionalProperties" => false,
            "properties" => FORMATTER_PROPERTIES
          }
        end

        def rules_schema
          {
            "type" => "object",
            "additionalProperties" => { "$ref" => "#/$defs/ruleConfig" },
            "propertyNames" => {
              "pattern" => "^[A-Za-z][A-Za-z0-9_]*$"
            }
          }
        end

        def definitions
          {
            "severity" => SEVERITY_SCHEMA,
            "ruleConfig" => {
              "oneOf" => [
                { "type" => "boolean" },
                rule_object_schema
              ]
            }
          }
        end

        def rule_object_schema
          {
            "type" => "object",
            "additionalProperties" => true,
            "properties" => {
              "enabled" => { "type" => "boolean" },
              "severity" => { "$ref" => "#/$defs/severity" },
              "pattern" => { "type" => "string" },
              "max_alternatives" => {
                "type" => "integer",
                "minimum" => 1
              }
            }
          }
        end

        def string_array_schema
          {
            "type" => "array",
            "items" => { "type" => "string" },
            "uniqueItems" => true
          }
        end
      end
    end
  end
end
