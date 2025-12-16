# frozen_string_literal: true

require "spec_helper"

Collie::Linter::Registry.load_rules

RSpec.describe Collie::Linter::Rules::DuplicateToken do
  def parse_grammar(source)
    lexer = Collie::Parser::Lexer.new(source)
    tokens = lexer.tokenize
    parser = Collie::Parser::Parser.new(tokens)
    parser.parse
  end

  describe "#check" do
    it "detects duplicate token declarations" do
      source = <<~GRAMMAR
        %token NUMBER
        %token NUMBER
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      rule = described_class.new
      offenses = rule.check(ast)

      expect(offenses.length).to eq(1)
      expect(offenses.first.message).to include("already defined")
    end

    it "allows different tokens" do
      source = <<~GRAMMAR
        %token NUMBER
        %token IDENTIFIER
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      rule = described_class.new
      offenses = rule.check(ast)

      expect(offenses).to be_empty
    end

    it "detects duplicates across multiple declarations" do
      source = <<~GRAMMAR
        %token NUMBER IDENTIFIER
        %token STRING NUMBER
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      rule = described_class.new
      offenses = rule.check(ast)

      expect(offenses.length).to eq(1)
      expect(offenses.first.message).to include("NUMBER")
    end
  end
end
