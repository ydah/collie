# frozen_string_literal: true

require "spec_helper"

Collie::Linter::Registry.load_rules

RSpec.describe Collie::Linter::Rules::TrailingWhitespace do
  let(:rule) { described_class.new({}) }
  let(:ast) { Collie::AST::GrammarFile.new(rules: [], declarations: []) }

  describe "#check" do
    it "detects trailing spaces" do
      source = "line with trailing spaces  \n"
      context = { source: source, file: "test.y" }

      offenses = rule.check(ast, context)
      expect(offenses).not_to be_empty
      expect(offenses.first.message).to include("Trailing whitespace")
    end

    it "detects trailing tabs" do
      source = "line with trailing tab\t\n"
      context = { source: source, file: "test.y" }

      offenses = rule.check(ast, context)
      expect(offenses).not_to be_empty
    end

    it "detects trailing whitespace at end of file" do
      source = "line with trailing spaces at EOF  "
      context = { source: source, file: "test.y" }

      offenses = rule.check(ast, context)
      expect(offenses).not_to be_empty
    end

    it "allows lines without trailing whitespace" do
      source = "clean line\nanother clean line\n"
      context = { source: source, file: "test.y" }

      offenses = rule.check(ast, context)
      expect(offenses).to be_empty
    end

    it "supports autocorrect" do
      source = "line with trailing spaces  \n"
      context = { source: source, file: "test.y" }

      offenses = rule.check(ast, context)
      expect(offenses.first.autocorrectable?).to be true
    end

    it "autocorrects by removing trailing whitespace" do
      source = "line one  \nline two\t\nline three"
      context = { source: source, file: "test.y" }

      offenses = rule.check(ast, context)
      offense = offenses.first
      offense.autocorrect.call

      expect(context[:source]).to eq("line one\nline two\nline three")
    end

    it "handles empty context" do
      offenses = rule.check(ast, {})
      expect(offenses).to be_empty
    end
  end
end
