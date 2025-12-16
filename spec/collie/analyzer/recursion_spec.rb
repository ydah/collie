# frozen_string_literal: true

require "spec_helper"

RSpec.describe Collie::Analyzer::Recursion do
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

  describe "#analyze" do
    it "detects direct left recursion" do
      grammar = create_grammar({
                                 "expr" => [%w[expr PLUS NUMBER], ["NUMBER"]]
                               })

      analyzer = described_class.new(grammar)
      result = analyzer.analyze

      expect(result[:left_recursive]).to include("expr")
    end

    it "detects direct right recursion" do
      grammar = create_grammar({
                                 "expr" => [%w[NUMBER PLUS expr], ["NUMBER"]]
                               })

      analyzer = described_class.new(grammar)
      result = analyzer.analyze

      expect(result[:right_recursive]).to include("expr")
    end

    it "detects no recursion in non-recursive rules" do
      grammar = create_grammar({
                                 "stmt" => [["NUMBER"], ["IDENTIFIER"]]
                               })

      analyzer = described_class.new(grammar)
      result = analyzer.analyze

      expect(result[:left_recursive]).to be_empty
      expect(result[:right_recursive]).to be_empty
    end

    it "handles rules with both left and right recursion" do
      grammar = create_grammar({
                                 "expr" => [
                                   %w[expr PLUS expr],
                                   ["NUMBER"]
                                 ]
                               })

      analyzer = described_class.new(grammar)
      result = analyzer.analyze

      expect(result[:left_recursive]).to include("expr")
      expect(result[:right_recursive]).to include("expr")
    end
  end

  describe "#left_recursive?" do
    it "returns true for left recursive rules" do
      grammar = create_grammar({
                                 "expr" => [%w[expr PLUS NUMBER]]
                               })

      analyzer = described_class.new(grammar)
      analyzer.analyze

      expect(analyzer.left_recursive?("expr")).to be true
    end

    it "returns false for non-left-recursive rules" do
      grammar = create_grammar({
                                 "expr" => [["NUMBER"]]
                               })

      analyzer = described_class.new(grammar)
      analyzer.analyze

      expect(analyzer.left_recursive?("expr")).to be false
    end
  end

  describe "#right_recursive?" do
    it "returns true for right recursive rules" do
      grammar = create_grammar({
                                 "expr" => [%w[NUMBER PLUS expr]]
                               })

      analyzer = described_class.new(grammar)
      analyzer.analyze

      expect(analyzer.right_recursive?("expr")).to be true
    end
  end
end
