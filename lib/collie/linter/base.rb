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
          autocorrect: autocorrect
        )
      end

      attr_reader :offenses
    end
  end
end
