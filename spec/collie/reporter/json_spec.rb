# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe Collie::Reporter::Json do
  let(:reporter) { described_class.new }
  let(:location) { Collie::AST::Location.new(file: "test.y", line: 10, column: 5, length: 3) }

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
    it "returns valid JSON" do
      offenses = [create_offense(:error, "Test error")]
      output = reporter.report(offenses)

      expect { JSON.parse(output) }.not_to raise_error
    end

    it "includes summary information" do
      offenses = [
        create_offense(:error, "Error 1"),
        create_offense(:warning, "Warning 1")
      ]
      output = reporter.report(offenses)
      data = JSON.parse(output)

      expect(data["summary"]["total"]).to eq(2)
      expect(data["summary"]["by_severity"]["error"]).to eq(1)
      expect(data["summary"]["by_severity"]["warning"]).to eq(1)
    end

    it "groups offenses by file" do
      offenses = [create_offense(:error, "Test error")]
      output = reporter.report(offenses)
      data = JSON.parse(output)

      expect(data["files"].length).to eq(1)
      expect(data["files"][0]["path"]).to eq("test.y")
    end

    it "includes offense details" do
      offenses = [create_offense(:error, "Test error")]
      output = reporter.report(offenses)
      data = JSON.parse(output)

      offense = data["files"][0]["offenses"][0]
      expect(offense["rule"]).to eq("TestRule")
      expect(offense["severity"]).to eq("error")
      expect(offense["message"]).to eq("Test error")
      expect(offense["location"]["line"]).to eq(10)
      expect(offense["location"]["column"]).to eq(5)
    end
  end
end
