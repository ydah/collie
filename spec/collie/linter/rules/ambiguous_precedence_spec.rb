# frozen_string_literal: true

require "spec_helper"

Collie::Linter::Registry.load_rules

RSpec.describe Collie::Linter::Rules::AmbiguousPrecedence do
  let(:rule) { described_class.new({}) }

  def create_grammar(rules_data:, precedence: [])
    rules = rules_data.map do |name, alternatives_data|
      alternatives = alternatives_data.map do |symbols_data|
        symbols = symbols_data.map do |sym_name|
          # Operators and uppercase names are terminals
          kind = if sym_name.match?(/^[A-Z]/) || sym_name.match?(/^[^a-z]/)
                   :terminal
                 else
                   :nonterminal
                 end
          Collie::AST::Symbol.new(
            name: sym_name,
            kind: kind,
            location: nil
          )
        end
        Collie::AST::Alternative.new(symbols: symbols, location: nil)
      end
      Collie::AST::Rule.new(name: name, alternatives: alternatives, location: nil)
    end

    declarations = precedence.map do |assoc, tokens|
      Collie::AST::PrecedenceDeclaration.new(
        associativity: assoc,
        tokens: tokens,
        location: nil
      )
    end

    Collie::AST::GrammarFile.new(rules: rules, declarations: declarations)
  end

  describe "#check" do
    it "detects operators without precedence" do
      grammar = create_grammar(
        rules_data: {
          "expr" => [%w[expr + expr], ["NUMBER"]]
        }
      )

      offenses = rule.check(grammar)
      expect(offenses).not_to be_empty
      expect(offenses.first.message).to include("does not have an explicit precedence")
    end

    it "allows operators with precedence declaration" do
      grammar = create_grammar(
        rules_data: {
          "expr" => [%w[expr + expr], ["NUMBER"]]
        },
        precedence: [
          [:left, ["+"]]
        ]
      )

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "allows alternatives with explicit %prec override" do
      symbols = [
        Collie::AST::Symbol.new(name: "expr", kind: :nonterminal, location: nil),
        Collie::AST::Symbol.new(name: "-", kind: :terminal, location: nil),
        Collie::AST::Symbol.new(name: "expr", kind: :nonterminal, location: nil)
      ]
      alternative = Collie::AST::Alternative.new(symbols: symbols, prec: "UMINUS", location: nil)
      grammar_rule = Collie::AST::Rule.new(name: "expr", alternatives: [alternative], location: nil)
      grammar = Collie::AST::GrammarFile.new(rules: [grammar_rule], declarations: [])

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "detects multiple operators without precedence" do
      grammar = create_grammar(
        rules_data: {
          "expr" => [%w[expr + expr], %w[expr * expr], ["NUMBER"]]
        },
        precedence: [
          [:left, ["+"]]
        ]
      )

      offenses = rule.check(grammar)
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include("*")
    end

    it "allows non-operator terminals" do
      grammar = create_grammar(
        rules_data: {
          "expr" => [["NUMBER"], ["IDENTIFIER"]]
        }
      )

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "checks operators in inline declarations" do
      symbols = [
        Collie::AST::Symbol.new(name: "expr", kind: :nonterminal, location: nil),
        Collie::AST::Symbol.new(name: "+", kind: :terminal, location: nil),
        Collie::AST::Symbol.new(name: "expr", kind: :nonterminal, location: nil)
      ]
      alternative = Collie::AST::Alternative.new(symbols: symbols, location: nil)
      declaration = Collie::AST::InlineRule.new(rule: "sum", alternatives: [alternative], location: nil)
      grammar = Collie::AST::GrammarFile.new(rules: [], declarations: [declaration])

      offenses = rule.check(grammar)
      expect(offenses.map(&:message)).to include("Operator '+' does not have an explicit precedence declaration")
    end
  end
end
