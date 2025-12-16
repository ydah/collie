# frozen_string_literal: true

require "spec_helper"

Collie::Linter::Registry.load_rules

RSpec.describe Collie::Linter::Rules::MissingStartSymbol do
  let(:rule) { described_class.new({}) }

  def create_grammar(rules_data: {}, start_symbol: nil)
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

    declarations = []
    declarations << Collie::AST::StartDeclaration.new(symbol: start_symbol, location: nil) if start_symbol

    Collie::AST::GrammarFile.new(rules: rules, declarations: declarations)
  end

  describe "#check" do
    it "allows grammar with explicit %start declaration" do
      grammar = create_grammar(
        rules_data: { "expr" => [["NUMBER"]] },
        start_symbol: "expr"
      )

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "allows grammar without %start but with rules" do
      grammar = create_grammar(
        rules_data: { "expr" => [["NUMBER"]] }
      )

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "detects missing %start with no rules" do
      grammar = create_grammar(rules_data: {})

      offenses = rule.check(grammar)
      expect(offenses).not_to be_empty
      expect(offenses.first.message).to include("No %start declaration and no rules defined")
    end
  end
end
