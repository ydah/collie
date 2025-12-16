# frozen_string_literal: true

require "spec_helper"

Collie::Linter::Registry.load_rules

RSpec.describe Collie::Linter::Rules::LongRule do
  def create_grammar_with_alternatives(count)
    alternatives = count.times.map do
      symbols = [Collie::AST::Symbol.new(name: "NUMBER", kind: :terminal, location: nil)]
      Collie::AST::Alternative.new(symbols: symbols, location: nil)
    end

    grammar_rule = Collie::AST::Rule.new(name: "expr", alternatives: alternatives, location: nil)
    Collie::AST::GrammarFile.new(rules: [grammar_rule], declarations: [])
  end

  describe "#check" do
    it "detects rule with too many alternatives" do
      rule = described_class.new({})
      grammar = create_grammar_with_alternatives(15)

      offenses = rule.check(grammar)
      expect(offenses).not_to be_empty
      expect(offenses.first.message).to include("has 15 alternatives")
    end

    it "allows rule with acceptable number of alternatives" do
      rule = described_class.new({})
      grammar = create_grammar_with_alternatives(5)

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "allows rule with exactly max alternatives" do
      rule = described_class.new({})
      grammar = create_grammar_with_alternatives(10)

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "respects custom max_alternatives from config" do
      config = {
        "rules" => {
          "LongRule" => {
            "max_alternatives" => 3
          }
        }
      }
      rule = described_class.new(config)
      grammar = create_grammar_with_alternatives(5)

      offenses = rule.check(grammar)
      expect(offenses).not_to be_empty
      expect(offenses.first.message).to include("max: 3")
    end
  end
end
