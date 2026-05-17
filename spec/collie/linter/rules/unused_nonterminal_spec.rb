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
        unused
            : item
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      offenses = described_class.new.check(ast)

      expect(offenses.map(&:message)).to include("Nonterminal 'unused' is defined but never used")
    end
  end
end
