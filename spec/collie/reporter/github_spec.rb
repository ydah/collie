# frozen_string_literal: true

require "spec_helper"

RSpec.describe Collie::Reporter::Github do
  let(:reporter) { described_class.new }

  def create_offense(severity, message, file: "test.y")
    rule_class = Class.new(Collie::Linter::Base) do
      self.rule_name = "TestRule"
      self.severity = severity
    end

    Collie::Linter::Offense.new(
      rule: rule_class,
      location: Collie::AST::Location.new(file: file, line: 10, column: 5),
      message: message
    )
  end

  describe "#report" do
    it "escapes workflow command data" do
      offense = create_offense(:warning, "bad 100%\nnext")
      output = reporter.report([offense])

      expect(output).to include("bad 100%25%0Anext")
    end

    it "escapes workflow command properties" do
      offense = create_offense(:error, "bad", file: "path,with:chars.y")
      output = reporter.report([offense])

      expect(output).to include("file=path%2Cwith%3Achars.y")
    end
  end
end
