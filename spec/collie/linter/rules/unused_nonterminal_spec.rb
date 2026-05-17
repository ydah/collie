# frozen_string_literal: true

require "spec_helper"

Collie::Linter::Registry.load_rules

RSpec.describe Collie::Linter::Rules::UnusedNonterminal do
  def parse_grammar(source)
    lexer = Collie::Parser::Lexer.new(source)
    tokens = lexer.tokenize
    parser = Collie::Parser::Parser.new(tokens)
    parser.parse
  end

  describe "#check" do
    it "does not count lowercase declared tokens as nonterminal usage" do
      source = <<~GRAMMAR
        %token item
        %%
        start
            : item
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      offenses = described_class.new.check(ast)

      expect(offenses).to be_empty
    end

    it "leaves unreachable rules to UnreachableRule" do
      source = <<~GRAMMAR
        %token ITEM
        %%
        start
            : ITEM
            ;
        unused
            : ITEM
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      offenses = described_class.new.check(ast)

      expect(offenses).to be_empty
    end
  end
end
