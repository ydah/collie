# frozen_string_literal: true

require "spec_helper"

RSpec.describe Collie::Analyzer::Reachability do
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
    it "marks all rules as reachable when connected" do
      grammar = create_grammar({
                                 "start" => [["expr"]],
                                 "expr" => [["NUMBER"], ["IDENTIFIER"]]
                               })

      analyzer = described_class.new(grammar)
      reachable = analyzer.analyze("start")

      expect(reachable).to include("start", "expr")
    end

    it "identifies unreachable rules" do
      grammar = create_grammar({
                                 "start" => [["NUMBER"]],
                                 "unused" => [["IDENTIFIER"]]
                               })

      analyzer = described_class.new(grammar)
      analyzer.analyze("start")

      expect(analyzer.unreachable_rules).to include("unused")
    end

    it "handles transitive reachability" do
      grammar = create_grammar({
                                 "start" => [["a"]],
                                 "a" => [["b"]],
                                 "b" => [["c"]],
                                 "c" => [["NUMBER"]],
                                 "unused" => [["IDENTIFIER"]]
                               })

      analyzer = described_class.new(grammar)
      reachable = analyzer.analyze("start")

      expect(reachable).to include("start", "a", "b", "c")
      expect(analyzer.unreachable_rules).to include("unused")
    end

    it "handles cyclic dependencies" do
      grammar = create_grammar({
                                 "start" => [["expr"]],
                                 "expr" => [%w[expr PLUS expr], ["NUMBER"]]
                               })

      analyzer = described_class.new(grammar)
      reachable = analyzer.analyze("start")

      expect(reachable).to include("start", "expr")
    end
  end

  describe "#unreachable_rules" do
    it "returns empty set when all rules are reachable" do
      grammar = create_grammar({
                                 "start" => [["expr"]],
                                 "expr" => [["NUMBER"]]
                               })

      analyzer = described_class.new(grammar)
      analyzer.analyze("start")

      expect(analyzer.unreachable_rules).to be_empty
    end

    it "handles multiple unreachable rules" do
      grammar = create_grammar({
                                 "start" => [["NUMBER"]],
                                 "unused1" => [["IDENTIFIER"]],
                                 "unused2" => [["STRING"]]
                               })

      analyzer = described_class.new(grammar)
      analyzer.analyze("start")

      expect(analyzer.unreachable_rules).to include("unused1", "unused2")
    end
  end
end
