# frozen_string_literal: true

require "spec_helper"

Collie::Linter::Registry.load_rules

RSpec.describe Collie::Linter::Rules::TokenNaming do
  def parse_grammar(source)
    lexer = Collie::Parser::Lexer.new(source)
    tokens = lexer.tokenize
    parser = Collie::Parser::Parser.new(tokens)
    parser.parse
  end

  describe "#check" do
    it "accepts UPPER_CASE tokens" do
      source = <<~GRAMMAR
        %token NUMBER IDENTIFIER MY_TOKEN
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      rule = described_class.new
      offenses = rule.check(ast)

      expect(offenses).to be_empty
    end

    it "rejects lowercase tokens" do
      source = <<~GRAMMAR
        %token number
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      rule = described_class.new
      offenses = rule.check(ast)

      expect(offenses.length).to eq(1)
      expect(offenses.first.message).to include("pattern")
    end

    it "rejects mixed case tokens" do
      source = <<~GRAMMAR
        %token MyToken
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      rule = described_class.new
      offenses = rule.check(ast)

      expect(offenses.length).to eq(1)
    end

    it "allows custom pattern via config" do
      source = <<~GRAMMAR
        %token mytoken
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      rule = described_class.new(pattern: "^[a-z]+$")
      offenses = rule.check(ast)

      expect(offenses).to be_empty
    end
  end
end
