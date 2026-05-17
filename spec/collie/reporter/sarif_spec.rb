# frozen_string_literal: true

require "json"
require "spec_helper"

RSpec.describe Collie::Reporter::Sarif do
  let(:reporter) { described_class.new }

  def create_offense(severity, message)
    rule_class = Class.new(Collie::Linter::Base) do
      self.rule_name = "TestRule"
      self.description = "Test rule description"
      self.severity = severity
    end

    Collie::Linter::Offense.new(
      rule: rule_class,
      location: Collie::AST::Location.new(file: "test.y", line: 10, column: 5, length: 3),
      message: message
    )
  end

  describe "#report" do
    it "returns SARIF 2.1.0 JSON" do
      data = JSON.parse(reporter.report([create_offense(:error, "Test error")]))

      expect(data["version"]).to eq("2.1.0")
      expect(data["runs"].first["tool"]["driver"]["name"]).to eq("Collie")
    end

    it "includes rule metadata and locations" do
      data = JSON.parse(reporter.report([create_offense(:warning, "Test warning")]))
      run = data["runs"].first
      result = run["results"].first

      expect(run["tool"]["driver"]["rules"].first["id"]).to eq("TestRule")
      expect(result["ruleId"]).to eq("TestRule")
      expect(result["level"]).to eq("warning")
      expect(result["locations"].first["physicalLocation"]["artifactLocation"]["uri"]).to eq("test.y")
      expect(result["locations"].first["physicalLocation"]["region"]["startLine"]).to eq(10)
    end
  end
end
