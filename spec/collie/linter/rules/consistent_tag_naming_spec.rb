# frozen_string_literal: true

require "spec_helper"

Collie::Linter::Registry.load_rules

RSpec.describe Collie::Linter::Rules::ConsistentTagNaming do
  let(:rule) { described_class.new({}) }

  def create_grammar(type_tags)
    declarations = type_tags.map do |tag|
      Collie::AST::TokenDeclaration.new(
        names: ["TOKEN"],
        type_tag: tag,
        location: nil
      )
    end

    Collie::AST::GrammarFile.new(rules: [], declarations: declarations)
  end

  describe "#check" do
    it "allows consistent snake_case tags" do
      grammar = create_grammar(%w[node_type expr_val stmt_info])

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "allows consistent camelCase tags" do
      grammar = create_grammar(%w[nodeType exprVal stmtInfo])

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "detects inconsistent tag naming" do
      grammar = create_grammar(%w[node_type nodeType])

      offenses = rule.check(grammar)
      expect(offenses).not_to be_empty
      expect(offenses.first.message).to include("Inconsistent type tag naming")
    end

    it "suggests the most common style" do
      grammar = create_grammar(%w[snake_one snake_two camelCase])

      offenses = rule.check(grammar)
      expect(offenses).not_to be_empty
      expect(offenses.first.message).to include("snake_case")
    end

    it "allows single type tag" do
      grammar = create_grammar(["node"])

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "allows no type tags" do
      grammar = create_grammar([])

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end
  end
end
