# frozen_string_literal: true

require "spec_helper"

Collie::Linter::Registry.load_rules

RSpec.describe Collie::Linter::Rules::EmptyAction do
  let(:rule) { described_class.new({}) }

  def create_grammar_with_action(action_code)
    symbols = [
      Collie::AST::Symbol.new(name: "NUMBER", kind: :terminal, location: nil)
    ]
    action = Collie::AST::Action.new(code: action_code, location: nil)
    alternative = Collie::AST::Alternative.new(symbols: symbols, action: action, location: nil)
    grammar_rule = Collie::AST::Rule.new(name: "expr", alternatives: [alternative], location: nil)

    Collie::AST::GrammarFile.new(rules: [grammar_rule], declarations: [])
  end

  describe "#check" do
    it "detects empty action" do
      grammar = create_grammar_with_action("")

      offenses = rule.check(grammar)
      expect(offenses).not_to be_empty
      expect(offenses.first.message).to include("Empty action block")
    end

    it "detects whitespace-only action" do
      grammar = create_grammar_with_action("   \n  \t  ")

      offenses = rule.check(grammar)
      expect(offenses).not_to be_empty
    end

    it "allows action with code" do
      grammar = create_grammar_with_action("$$ = $1;")

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "allows alternative without action" do
      symbols = [
        Collie::AST::Symbol.new(name: "NUMBER", kind: :terminal, location: nil)
      ]
      alternative = Collie::AST::Alternative.new(symbols: symbols, action: nil, location: nil)
      grammar_rule = Collie::AST::Rule.new(name: "expr", alternatives: [alternative], location: nil)
      grammar = Collie::AST::GrammarFile.new(rules: [grammar_rule], declarations: [])

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "supports autocorrect" do
      grammar = create_grammar_with_action("")
      offenses = rule.check(grammar)

      expect(offenses.first.autocorrectable?).to be true
    end
  end
end
