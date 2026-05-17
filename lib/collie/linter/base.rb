# frozen_string_literal: true

require_relative "../ast"
require_relative "registry"

module Collie
  module Linter
    # Offense representation
    class Offense
      attr_reader :rule, :location, :message, :severity, :autocorrect

      def initialize(rule:, location:, message:, severity: nil, autocorrect: nil)
        @rule = rule
        @location = location
        @message = message
        @severity = severity || rule.severity
        @autocorrect = autocorrect
      end

      def autocorrectable?
        !@autocorrect.nil?
      end

      def to_s
        "#{location}: #{severity}: [#{rule.rule_name}] #{message}"
      end
    end

    # Base class for all lint rules
    class Base
      VALID_SEVERITIES = %i[error warning convention info].freeze

      class << self
        attr_accessor :rule_name, :description, :severity, :autocorrectable
      end

      def initialize(config = {})
        @config = config
        @offenses = []
      end

      def check(_ast, _context = {})
        raise NotImplementedError, "#{self.class} must implement #check"
      end

      def autocorrectable?
        self.class.autocorrectable
      end

      protected

      def add_offense(node, message:, autocorrect: nil)
        @offenses << Offense.new(
          rule: self.class,
          location: node.location,
          message: message,
          severity: configured_severity,
          autocorrect: autocorrect
        )
      end

      attr_reader :offenses

      def configured_severity
        severity = config_value(:severity)
        return self.class.severity unless severity

        normalized = severity.to_sym
        VALID_SEVERITIES.include?(normalized) ? normalized : self.class.severity
      end

      def config_value(key, default = nil)
        string_key = key.to_s
        return @config[string_key] if @config.key?(string_key)
        return @config[key] if @config.key?(key)

        default
      end

      def each_rule_like(ast)
        ast.rules.each { |rule| yield rule }

        ast.declarations.each do |declaration|
          next unless rule_like_declaration?(declaration)

          yield declaration
        end
      end

      def rule_like_declaration?(declaration)
        declaration.is_a?(AST::ParameterizedRule) || declaration.is_a?(AST::InlineRule)
      end

      def rule_like_name(rule)
        rule.is_a?(AST::InlineRule) ? rule.rule : rule.name
      end

      def rule_like_parameters(rule)
        rule.respond_to?(:parameters) ? rule.parameters : []
      end
    end
  end
end
