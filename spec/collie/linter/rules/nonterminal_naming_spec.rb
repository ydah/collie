# frozen_string_literal: true

require "spec_helper"

Collie::Linter::Registry.load_rules

RSpec.describe Collie::Linter::Rules::NonterminalNaming do
  describe "#check" do
    it "checks inline declaration names" do
      declaration = Collie::AST::InlineRule.new(rule: "BadName", alternatives: [], location: nil)
      grammar = Collie::AST::GrammarFile.new(rules: [], declarations: [declaration])

      offenses = described_class.new.check(grammar)

      expect(offenses.map(&:message)).to include(
        "Nonterminal 'BadName' should match pattern /^[a-z][a-z0-9_]*$/"
      )
    end
  end
end
