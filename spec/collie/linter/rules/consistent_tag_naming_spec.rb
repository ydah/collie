# frozen_string_literal: true

require "spec_helper"

Collie::Linter::Registry.load_rules

RSpec.describe Collie::Linter::Rules::ConsistentTagNaming do
  let(:rule) { described_class.new({}) }

  def create_grammar(type_tags)
    declarations = type_tags.each_with_index.map do |tag, index|
      Collie::AST::TokenDeclaration.new(
        names: ["TOKEN"],
        type_tag: tag,
        location: Collie::AST::Location.new(file: "test.y", line: index + 1, column: 1)
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
      expect(offenses.first.message).to include("different naming style")
    end

    it "suggests the most common style" do
      grammar = create_grammar(%w[snake_one snake_two camelCase])

      offenses = rule.check(grammar)
      expect(offenses).not_to be_empty
      expect(offenses.first.message).to include("snake_case")
      expect(offenses.first.location.line).to eq(3)
    end

    it "reports each outlier location" do
      grammar = create_grammar(%w[snake_one snake_two camelCase PascalCase])

      offenses = rule.check(grammar)
      expect(offenses.map { |offense| offense.location.line }).to eq([3, 4])
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
