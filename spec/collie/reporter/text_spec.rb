# frozen_string_literal: true

require "spec_helper"

RSpec.describe Collie::Reporter::Text do
  let(:reporter) { described_class.new(colorize: false) }
  let(:location) { Collie::AST::Location.new(file: "test.y", line: 10, column: 5) }

  def create_offense(severity, message)
    rule_class = Class.new(Collie::Linter::Base) do
      self.rule_name = "TestRule"
      self.severity = severity
    end

    Collie::Linter::Offense.new(
      rule: rule_class,
      location: location,
      message: message
    )
  end

  describe "#report" do
    it "reports success when no offenses" do
      output = reporter.report([])
      expect(output).to include("No offenses detected")
    end

    it "reports single offense" do
      offenses = [create_offense(:error, "Test error")]
      output = reporter.report(offenses)

      expect(output).to include("test.y")
      expect(output).to include("10:5")
      expect(output).to include("error")
      expect(output).to include("Test error")
    end

    it "groups offenses by file" do
      offenses = [
        create_offense(:error, "Error 1"),
        create_offense(:warning, "Warning 1")
      ]
      output = reporter.report(offenses)

      expect(output).to include("test.y")
      expect(output.scan("test.y").length).to eq(1) # File name appears once
    end

    it "includes summary with counts" do
      offenses = [
        create_offense(:error, "Error 1"),
        create_offense(:error, "Error 2"),
        create_offense(:warning, "Warning 1")
      ]
      output = reporter.report(offenses)

      expect(output).to include("2 error(s)")
      expect(output).to include("1 warning(s)")
    end

    it "sorts offenses by location" do
      loc1 = Collie::AST::Location.new(file: "test.y", line: 20, column: 1)
      loc2 = Collie::AST::Location.new(file: "test.y", line: 10, column: 1)

      rule_class = Class.new(Collie::Linter::Base) do
        self.rule_name = "TestRule"
        self.severity = :error
      end

      offense1 = Collie::Linter::Offense.new(
        rule: rule_class,
        location: loc1,
        message: "Later offense"
      )

      offense2 = Collie::Linter::Offense.new(
        rule: rule_class,
        location: loc2,
        message: "Earlier offense"
      )

      output = reporter.report([offense1, offense2])

      earlier_pos = output.index("Earlier offense")
      later_pos = output.index("Later offense")

      expect(earlier_pos).to be < later_pos
    end
  end
end
