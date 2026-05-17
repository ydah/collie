# frozen_string_literal: true

require "spec_helper"

Collie::Linter::Registry.load_rules

RSpec.describe Collie::Linter::Rules::FactorizableRules do
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
    it "detects alternatives with common prefix" do
      grammar = create_grammar([
                                 %w[IF EXPR THEN STMT],
                                 %w[IF EXPR THEN STMT ELSE STMT]
                               ])

      offenses = rule.check(grammar)
      expect(offenses).not_to be_empty
      expect(offenses.first.message).to include("common prefix")
    end

    it "allows alternatives without common prefix" do
      grammar = create_grammar([
                                 %w[IF EXPR],
                                 %w[WHILE EXPR]
                               ])

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "allows single alternative" do
      grammar = create_grammar([
                                 %w[IF EXPR THEN STMT]
                               ])

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "requires minimum prefix length of 2" do
      grammar = create_grammar([
                                 %w[IF A],
                                 %w[IF B]
                               ])

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "detects longer common prefix" do
      grammar = create_grammar([
                                 %w[A B C D],
                                 %w[A B C E]
                               ])

      offenses = rule.check(grammar)
      expect(offenses).not_to be_empty
      expect(offenses.first.message).to include("3 symbols")
    end

    it "checks inline declarations" do
      alternatives = [
        %w[IF EXPR THEN STMT],
        %w[IF EXPR THEN STMT ELSE STMT]
      ].map do |symbols_data|
        symbols = symbols_data.map do |sym_name|
          Collie::AST::Symbol.new(name: sym_name, kind: :terminal, location: nil)
        end
        Collie::AST::Alternative.new(symbols: symbols, location: nil)
      end
      declaration = Collie::AST::InlineRule.new(rule: "branch", alternatives: alternatives, location: nil)
      grammar = Collie::AST::GrammarFile.new(rules: [], declarations: [declaration])

      offenses = rule.check(grammar)
      expect(offenses.map(&:message)).to include(
        "Rule 'branch' has 2 alternatives with common prefix (4 symbols). Consider factoring."
      )
    end
  end
end
