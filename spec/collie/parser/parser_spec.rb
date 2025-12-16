# frozen_string_literal: true

require "spec_helper"

RSpec.describe Collie::Parser::Parser do
  describe "#parse" do
    it "parses empty grammar" do
      source = "%%\n%%"
      lexer = Collie::Parser::Lexer.new(source)
      tokens = lexer.tokenize
      parser = described_class.new(tokens)
      ast = parser.parse

      expect(ast).to be_a(Collie::AST::GrammarFile)
      expect(ast.declarations).to be_empty
      expect(ast.rules).to be_empty
    end

    it "parses prologue section" do
      source = <<~GRAMMAR
        %{
        #include <stdio.h>
        %}
        %%
        %%
      GRAMMAR

      lexer = Collie::Parser::Lexer.new(source)
      tokens = lexer.tokenize
      parser = described_class.new(tokens)
      ast = parser.parse

      expect(ast.prologue).to be_a(Collie::AST::Prologue)
      expect(ast.prologue.code).to include("stdio.h")
    end

    it "parses token declarations" do
      source = <<~GRAMMAR
        %token NUMBER IDENTIFIER
        %token <node> PLUS MINUS
        %%
        %%
      GRAMMAR

      lexer = Collie::Parser::Lexer.new(source)
      tokens = lexer.tokenize
      parser = described_class.new(tokens)
      ast = parser.parse

      expect(ast.declarations.length).to eq(2)
      expect(ast.declarations[0]).to be_a(Collie::AST::TokenDeclaration)
      expect(ast.declarations[0].names).to eq(%w[NUMBER IDENTIFIER])
      expect(ast.declarations[1].type_tag).to eq("node")
    end

    it "parses type declarations" do
      source = <<~GRAMMAR
        %type <node> expr stmt
        %%
        %%
      GRAMMAR

      lexer = Collie::Parser::Lexer.new(source)
      tokens = lexer.tokenize
      parser = described_class.new(tokens)
      ast = parser.parse

      expect(ast.declarations.length).to eq(1)
      decl = ast.declarations.first
      expect(decl).to be_a(Collie::AST::TypeDeclaration)
      expect(decl.type_tag).to eq("node")
      expect(decl.names).to eq(%w[expr stmt])
    end

    it "parses precedence declarations" do
      source = <<~GRAMMAR
        %left PLUS MINUS
        %right ASSIGN
        %nonassoc EQ NE
        %%
        %%
      GRAMMAR

      lexer = Collie::Parser::Lexer.new(source)
      tokens = lexer.tokenize
      parser = described_class.new(tokens)
      ast = parser.parse

      expect(ast.declarations.length).to eq(3)
      expect(ast.declarations[0].associativity).to eq(:left)
      expect(ast.declarations[1].associativity).to eq(:right)
      expect(ast.declarations[2].associativity).to eq(:nonassoc)
    end

    it "parses start declaration" do
      source = <<~GRAMMAR
        %start program
        %%
        %%
      GRAMMAR

      lexer = Collie::Parser::Lexer.new(source)
      tokens = lexer.tokenize
      parser = described_class.new(tokens)
      ast = parser.parse

      start_decl = ast.declarations.find { |d| d.is_a?(Collie::AST::StartDeclaration) }
      expect(start_decl).not_to be_nil
      expect(start_decl.symbol).to eq("program")
    end

    it "parses simple rules" do
      source = <<~GRAMMAR
        %%
        expr
            : NUMBER
            | IDENTIFIER
            ;
        %%
      GRAMMAR

      lexer = Collie::Parser::Lexer.new(source)
      tokens = lexer.tokenize
      parser = described_class.new(tokens)
      ast = parser.parse

      expect(ast.rules.length).to eq(1)
      rule = ast.rules.first
      expect(rule.name).to eq("expr")
      expect(rule.alternatives.length).to eq(2)
    end

    it "parses rules with actions" do
      source = <<~GRAMMAR
        %%
        expr
            : expr PLUS expr { $$ = $1 + $3; }
            ;
        %%
      GRAMMAR

      lexer = Collie::Parser::Lexer.new(source)
      tokens = lexer.tokenize
      parser = described_class.new(tokens)
      ast = parser.parse

      rule = ast.rules.first
      alt = rule.alternatives.first
      expect(alt.action).not_to be_nil
      expect(alt.action.code).to include("$$ = $1 + $3;")
    end

    it "parses rules with precedence" do
      source = <<~GRAMMAR
        %%
        expr
            : MINUS expr %prec UMINUS
            ;
        %%
      GRAMMAR

      lexer = Collie::Parser::Lexer.new(source)
      tokens = lexer.tokenize
      parser = described_class.new(tokens)
      ast = parser.parse

      rule = ast.rules.first
      alt = rule.alternatives.first
      expect(alt.prec).to eq("UMINUS")
    end

    it "parses epilogue section" do
      source = <<~GRAMMAR
        %%
        %%
        int main() {
          return 0;
        }
      GRAMMAR

      lexer = Collie::Parser::Lexer.new(source)
      tokens = lexer.tokenize
      parser = described_class.new(tokens)
      ast = parser.parse

      expect(ast.epilogue).not_to be_nil
      expect(ast.epilogue.code).to include("main")
    end

    it "parses complete grammar with all sections" do
      source = <<~GRAMMAR
        %{
        #include <stdio.h>
        %}

        %token NUMBER
        %left PLUS

        %%

        expr
            : expr PLUS expr { $$ = $1 + $3; }
            | NUMBER
            ;

        %%

        int main() { return 0; }
      GRAMMAR

      lexer = Collie::Parser::Lexer.new(source)
      tokens = lexer.tokenize
      parser = described_class.new(tokens)
      ast = parser.parse

      expect(ast.prologue).not_to be_nil
      expect(ast.declarations).not_to be_empty
      expect(ast.rules).not_to be_empty
      expect(ast.epilogue).not_to be_nil
    end

    it "handles multiple rules" do
      source = <<~GRAMMAR
        %%
        program
            : stmt_list
            ;

        stmt_list
            : stmt
            | stmt_list stmt
            ;

        stmt
            : expr
            ;

        expr
            : NUMBER
            ;
        %%
      GRAMMAR

      lexer = Collie::Parser::Lexer.new(source)
      tokens = lexer.tokenize
      parser = described_class.new(tokens)
      ast = parser.parse

      expect(ast.rules.length).to eq(4)
      expect(ast.rules.map(&:name)).to eq(%w[program stmt_list stmt expr])
    end
  end
end
