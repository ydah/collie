# frozen_string_literal: true

require "spec_helper"

Collie::Linter::Registry.load_rules

RSpec.describe Collie::Linter::Rules::RedundantEpsilon do
  let(:rule) { described_class.new({}) }

  def create_grammar(alternatives_data)
    alternatives = alternatives_data.map do |symbols_data|
      symbols = symbols_data.map do |sym_name|
        Collie::AST::Symbol.new(
          name: sym_name,
          kind: :terminal,
          location: nil
        )
      end
      Collie::AST::Alternative.new(symbols: symbols, location: nil)
    end

    grammar_rule = Collie::AST::Rule.new(name: "expr", alternatives: alternatives, location: nil)
    Collie::AST::GrammarFile.new(rules: [grammar_rule], declarations: [])
  end

  describe "#check" do
    it "allows a single epsilon production with other alternatives" do
      grammar = create_grammar([
                                 ["NUMBER"],
                                 [] # Empty/epsilon
                               ])

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "allows rule with only non-epsilon alternatives" do
      grammar = create_grammar([
                                 ["NUMBER"],
                                 ["IDENTIFIER"]
                               ])

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "allows rule with only epsilon production" do
      grammar = create_grammar([
                                 [] # Only epsilon
                               ])

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "detects multiple epsilon productions" do
      grammar = create_grammar([
                                 ["NUMBER"],
                                 [], # First epsilon
                                 [] # Second epsilon (unusual but possible)
                               ])

      offenses = rule.check(grammar)
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include("multiple epsilon productions")
    end

    it "detects duplicate explicit empty productions" do
      empty_alternatives = [
        Collie::AST::Alternative.new(explicit_empty: true, location: nil),
        Collie::AST::Alternative.new(explicit_empty: true, location: nil)
      ]
      grammar_rule = Collie::AST::Rule.new(name: "expr", alternatives: empty_alternatives, location: nil)
      grammar = Collie::AST::GrammarFile.new(rules: [grammar_rule], declarations: [])

      offenses = rule.check(grammar)
      expect(offenses.size).to eq(1)
    end

    it "detects duplicate epsilon productions in inline declarations" do
      empty_alternatives = [
        Collie::AST::Alternative.new(explicit_empty: true, location: nil),
        Collie::AST::Alternative.new(explicit_empty: true, location: nil)
      ]
      declaration = Collie::AST::InlineRule.new(rule: "opt", alternatives: empty_alternatives, location: nil)
      grammar = Collie::AST::GrammarFile.new(rules: [], declarations: [declaration])

      offenses = rule.check(grammar)
      expect(offenses.map(&:message)).to include(
        "Rule 'opt' has multiple epsilon productions. Keep one empty alternative and remove duplicates."
      )
    end
  end
end
