# frozen_string_literal: true

require "spec_helper"

RSpec.describe Collie::Formatter::Formatter do
  let(:formatter) { described_class.new }

  def parse_grammar(source)
    lexer = Collie::Parser::Lexer.new(source)
    tokens = lexer.tokenize
    parser = Collie::Parser::Parser.new(tokens)
    parser.parse
  end

  describe "#format" do
    it "formats token declarations" do
      source = <<~GRAMMAR
        %token NUMBER IDENTIFIER
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("%token")
      expect(output).to include("NUMBER")
    end

    it "aligns token declarations with type tags" do
      source = <<~GRAMMAR
        %token <node> NUMBER
        %token <id> IDENTIFIER
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("<node>")
      expect(output).to include("<id>")
    end

    it "formats precedence declarations" do
      source = <<~GRAMMAR
        %left PLUS MINUS
        %right ASSIGN
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("%left")
      expect(output).to include("%right")
    end

    it "formats simple rules" do
      source = <<~GRAMMAR
        %%
        expr
            : NUMBER
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("expr")
      expect(output).to include(": NUMBER")
    end

    it "formats rules with multiple alternatives" do
      source = <<~GRAMMAR
        %%
        expr
            : NUMBER
            | IDENTIFIER
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include(": NUMBER")
      expect(output).to include("| IDENTIFIER")
    end

    it "preserves actions in rules" do
      source = <<~GRAMMAR
        %%
        expr
            : NUMBER { $$ = $1; }
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("{ $$ = $1; }")
    end

    it "formats complete grammar" do
      source = <<~GRAMMAR
        %token NUMBER
        %left PLUS

        %%

        expr
            : expr PLUS expr
            | NUMBER
            ;

        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("%token")
      expect(output).to include("NUMBER")
      expect(output).to include("%left")
      expect(output).to include("PLUS")
      expect(output).to include("%%")
      expect(output).to include("expr")
    end

    it "includes prologue if present" do
      source = <<~GRAMMAR
        %{
        #include <stdio.h>
        %}
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("%{")
      expect(output).to include("stdio.h")
      expect(output).to include("%}")
    end

    it "includes epilogue if present" do
      source = <<~GRAMMAR
        %%
        %%
        int main() { return 0; }
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("main")
    end
  end
end
