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

    it "allows tokens declared by precedence directives" do
      source = <<~GRAMMAR
        %left PLUS
        %%
        expr
            : expr PLUS expr
            | %empty
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      rule = described_class.new
      offenses = rule.check(ast)

      expect(offenses).to be_empty
    end

    it "allows parameterized rule calls declared in the declaration section" do
      source = <<~GRAMMAR
        %token NUMBER
        %rule list(X): X ;
        %%
        start
            : list(expr)
            ;
        expr
            : NUMBER
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      rule = described_class.new
      offenses = rule.check(ast)

      expect(offenses).to be_empty
    end

    it "checks parameterized call arguments" do
      source = <<~GRAMMAR
        %rule list(X): X ;
        %%
        start
            : list(missing)
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      rule = described_class.new
      offenses = rule.check(ast)

      expect(offenses.map(&:message)).to include("Undefined symbol 'missing'")
    end

    it "checks parameterized rule declaration bodies without flagging parameters" do
      source = <<~GRAMMAR
        %token NUMBER
        %rule list(X): X missing ;
        %%
        start
            : list(NUMBER)
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      rule = described_class.new
      offenses = rule.check(ast)

      expect(offenses.map(&:message)).to eq(["Undefined symbol 'missing'"])
    end

    it "checks inline rule declaration bodies without flagging parameters" do
      source = <<~GRAMMAR
        %inline opt(X): X | missing ;
        %%
        start
            : opt(value)
            ;
        value
            : %empty
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      rule = described_class.new
      offenses = rule.check(ast)

      expect(offenses.map(&:message)).to include("Undefined symbol 'missing'")
      expect(offenses.map(&:message)).not_to include("Undefined symbol 'X'")
    end

    it "detects undefined %start symbols" do
      source = <<~GRAMMAR
        %start missing
        %%
        expr
            : NUMBER
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      rule = described_class.new
      offenses = rule.check(ast)

      expect(offenses.map(&:message)).to include("Undefined start symbol 'missing'")
    end

    it "detects undefined %type symbols" do
      source = <<~GRAMMAR
        %type <node> missing
        %%
        expr
            : NUMBER
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      rule = described_class.new
      offenses = rule.check(ast)

      expect(offenses.map(&:message)).to include("%type references undefined symbol 'missing'")
    end
  end
end
