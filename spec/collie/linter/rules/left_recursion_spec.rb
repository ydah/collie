# frozen_string_literal: true

require "spec_helper"

Collie::Linter::Registry.load_rules

RSpec.describe Collie::Linter::Rules::LeftRecursion do
  let(:rule) { described_class.new({}) }

  def create_grammar(rules_data)
    rules = rules_data.map do |name, alternatives_data|
      alternatives = alternatives_data.map do |symbols_data|
        symbols = symbols_data.map do |sym_name|
          Collie::AST::Symbol.new(
            name: sym_name,
            kind: sym_name.match?(/^[A-Z]/) ? :terminal : :nonterminal,
            location: nil
          )
        end
        Collie::AST::Alternative.new(symbols: symbols, location: nil)
      end
      Collie::AST::Rule.new(name: name, alternatives: alternatives, location: nil)
    end

    Collie::AST::GrammarFile.new(rules: rules, declarations: [])
  end

  describe "#check" do
    it "detects direct left recursion" do
      grammar = create_grammar({
                                 "expr" => [%w[expr PLUS NUMBER], ["NUMBER"]]
                               })

      offenses = rule.check(grammar)
      expect(offenses).not_to be_empty
      expect(offenses.first.message).to include("left recursion")
    end

    it "detects indirect left recursion" do
      grammar = create_grammar({
                                 "a" => [["b"]],
                                 "b" => [["a"], ["NUMBER"]]
                               })

      offenses = rule.check(grammar)
      expect(offenses).not_to be_empty
    end

    it "allows non-left-recursive rules" do
      grammar = create_grammar({
                                 "expr" => [["NUMBER"], ["IDENTIFIER"]]
                               })

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "allows right recursion" do
      grammar = create_grammar({
                                 "expr" => [%w[NUMBER PLUS expr], ["NUMBER"]]
                               })

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end
  end
end
