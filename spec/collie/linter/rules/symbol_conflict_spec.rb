# frozen_string_literal: true

require "spec_helper"

Collie::Linter::Registry.load_rules

RSpec.describe Collie::Linter::Rules::SymbolConflict do
  def parse_grammar(source)
    lexer = Collie::Parser::Lexer.new(source)
    tokens = lexer.tokenize
    parser = Collie::Parser::Parser.new(tokens)
    parser.parse
  end

  describe "#check" do
    it "detects token and nonterminal name conflicts" do
      source = <<~GRAMMAR
        %token expr
        %%
        expr
            : expr
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      offenses = described_class.new.check(ast)

      expect(offenses.map(&:message)).to include("Symbol 'expr' is declared as both token and nonterminal")
    end

    it "detects duplicate nonterminal definitions" do
      source = <<~GRAMMAR
        %%
        expr
            : NUMBER
            ;
        expr
            : IDENTIFIER
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      offenses = described_class.new.check(ast)

      expect(offenses.map(&:message).join("\n")).to include("Nonterminal 'expr' already defined")
    end

    it "allows distinct tokens and nonterminals" do
      source = <<~GRAMMAR
        %token NUMBER
        %%
        expr
            : NUMBER
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      offenses = described_class.new.check(ast)

      expect(offenses).to be_empty
    end
  end
end
