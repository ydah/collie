# frozen_string_literal: true

require "spec_helper"

Collie::Linter::Registry.load_rules

RSpec.describe Collie::Linter::Rules::PrecImprovement do
  let(:rule) { described_class.new({}) }

  def create_grammar(alternatives_data:, precedence: [])
    alternatives = alternatives_data.map do |symbols_data, prec|
      symbols = symbols_data.map do |sym_name|
        Collie::AST::Symbol.new(
          name: sym_name,
          kind: :terminal,
          location: nil
        )
      end
      Collie::AST::Alternative.new(symbols: symbols, prec: prec, location: nil)
    end

    grammar_rule = Collie::AST::Rule.new(name: "expr", alternatives: alternatives, location: nil)

    declarations = precedence.map do |assoc, tokens|
      Collie::AST::PrecedenceDeclaration.new(
        associativity: assoc,
        tokens: tokens,
        location: nil
      )
    end

    Collie::AST::GrammarFile.new(rules: [grammar_rule], declarations: declarations)
  end

  describe "#check" do
    it "detects %prec without precedence declaration" do
      grammar = create_grammar(
        alternatives_data: [
          [%w[NUMBER], "UMINUS"]
        ]
      )

      offenses = rule.check(grammar)
      expect(offenses).not_to be_empty
      expect(offenses.first.message).to include("not declared in precedence directives")
    end

    it "allows %prec with precedence declaration" do
      grammar = create_grammar(
        alternatives_data: [
          [%w[NUMBER], "UMINUS"]
        ],
        precedence: [
          [:right, ["UMINUS"]]
        ]
      )

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "allows alternative without %prec" do
      grammar = create_grammar(
        alternatives_data: [
          [%w[NUMBER], nil]
        ]
      )

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end
  end
end
