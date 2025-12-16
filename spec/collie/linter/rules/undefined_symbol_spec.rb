# frozen_string_literal: true

require "spec_helper"

Collie::Linter::Registry.load_rules

RSpec.describe Collie::Linter::Rules::UndefinedSymbol do
  def parse_grammar(source)
    lexer = Collie::Parser::Lexer.new(source)
    tokens = lexer.tokenize
    parser = Collie::Parser::Parser.new(tokens)
    parser.parse
  end

  describe "#check" do
    it "detects undefined terminal symbols" do
      source = <<~GRAMMAR
        %token NUMBER
        %%
        expr
            : UNDEFINED_TOKEN
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      rule = described_class.new
      offenses = rule.check(ast)

      expect(offenses.length).to eq(1)
      expect(offenses.first.message).to include("UNDEFINED_TOKEN")
    end

    it "detects undefined nonterminal symbols" do
      source = <<~GRAMMAR
        %token NUMBER
        %%
        expr
            : undefined_rule
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      rule = described_class.new
      offenses = rule.check(ast)

      expect(offenses.length).to eq(1)
      expect(offenses.first.message).to include("undefined_rule")
    end

    it "allows defined symbols" do
      source = <<~GRAMMAR
        %token NUMBER
        %%
        expr
            : NUMBER
            | other
            ;
        other
            : NUMBER
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      rule = described_class.new
      offenses = rule.check(ast)

      expect(offenses).to be_empty
    end
  end
end
