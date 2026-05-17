# frozen_string_literal: true

require "spec_helper"

Collie::Linter::Registry.load_rules

RSpec.describe Collie::Linter::Rules::UnusedToken do
  def parse_grammar(source)
    lexer = Collie::Parser::Lexer.new(source)
    tokens = lexer.tokenize
    parser = Collie::Parser::Parser.new(tokens)
    parser.parse
  end

  describe "#check" do
    it "treats parameterized call arguments as token usage" do
      source = <<~GRAMMAR
        %token ITEM
        %rule list(X): X ;
        %%
        start
            : list(ITEM)
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      rule = described_class.new
      offenses = rule.check(ast)

      expect(offenses).to be_empty
    end

    it "treats lowercase declared tokens as token usage" do
      source = <<~GRAMMAR
        %token item
        %%
        start
            : item
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      rule = described_class.new
      offenses = rule.check(ast)

      expect(offenses).to be_empty
    end

    it "reports unused tokens declared by precedence directives" do
      source = <<~GRAMMAR
        %left PLUS
        %%
        start
            : %empty
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      rule = described_class.new
      offenses = rule.check(ast)

      expect(offenses.map(&:message)).to include("Token 'PLUS' is declared but never used")
    end

    it "treats %prec annotations as token usage" do
      source = <<~GRAMMAR
        %left UMINUS
        %%
        start
            : MINUS start %prec UMINUS
            | NUMBER
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
