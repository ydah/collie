# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Lrama extensions parsing" do
  describe "parameterized rules" do
    it "parses parameterized rule definition" do
      source = <<~GRAMMAR
        %%
        pair(X, Y)
            : X COMMA Y
            ;
        %%
      GRAMMAR

      lexer = Collie::Parser::Lexer.new(source)
      tokens = lexer.tokenize
      parser = Collie::Parser::Parser.new(tokens)
      ast = parser.parse

      expect(ast.rules.length).to eq(1)
      rule = ast.rules.first
      expect(rule).to be_a(Collie::AST::ParameterizedRule)
      expect(rule.name).to eq("pair")
      expect(rule.parameters).to eq(%w[X Y])
    end

    it "parses regular rules without parameters" do
      source = <<~GRAMMAR
        %%
        expr
            : NUMBER
            ;
        %%
      GRAMMAR

      lexer = Collie::Parser::Lexer.new(source)
      tokens = lexer.tokenize
      parser = Collie::Parser::Parser.new(tokens)
      ast = parser.parse

      expect(ast.rules.length).to eq(1)
      rule = ast.rules.first
      expect(rule).to be_a(Collie::AST::Rule)
      expect(rule.name).to eq("expr")
    end
  end

  describe "named references" do
    it "parses symbols with named references" do
      source = <<~GRAMMAR
        %%
        expr
            : IDENTIFIER[var] '=' NUMBER[val]
            ;
        %%
      GRAMMAR

      lexer = Collie::Parser::Lexer.new(source)
      tokens = lexer.tokenize
      parser = Collie::Parser::Parser.new(tokens)
      ast = parser.parse

      rule = ast.rules.first
      alt = rule.alternatives.first
      expect(alt.symbols.length).to eq(3)
      expect(alt.symbols[0].name).to eq("IDENTIFIER")
      expect(alt.symbols[0].alias_name).to eq("var")
      expect(alt.symbols[2].alias_name).to eq("val")
    end
  end

  describe "%rule declaration" do
    it "parses %rule declaration with parameters" do
      source = <<~GRAMMAR
        %rule pair(X, Y): X COMMA Y ;
        %%
        %%
      GRAMMAR

      lexer = Collie::Parser::Lexer.new(source)
      tokens = lexer.tokenize
      parser = Collie::Parser::Parser.new(tokens)
      ast = parser.parse

      expect(ast.declarations.length).to eq(1)
      decl = ast.declarations.first
      expect(decl).to be_a(Collie::AST::ParameterizedRule)
      expect(decl.name).to eq("pair")
      expect(decl.parameters).to eq(%w[X Y])
    end
  end

  describe "%inline declaration" do
    it "parses %inline declaration" do
      source = <<~GRAMMAR
        %inline opt
        %%
        %%
      GRAMMAR

      lexer = Collie::Parser::Lexer.new(source)
      tokens = lexer.tokenize
      parser = Collie::Parser::Parser.new(tokens)
      ast = parser.parse

      expect(ast.declarations.length).to eq(1)
      decl = ast.declarations.first
      expect(decl).to be_a(Collie::AST::InlineRule)
      expect(decl.rule).to eq("opt")
    end
  end

  describe "complete Lrama grammar" do
    it "parses a grammar with multiple Lrama features" do
      fixture_path = File.expand_path("../../fixtures/lrama_extensions.y", __dir__)
      source = File.read(fixture_path)

      lexer = Collie::Parser::Lexer.new(source, filename: fixture_path)
      tokens = lexer.tokenize
      parser = Collie::Parser::Parser.new(tokens)
      ast = parser.parse

      expect(ast).to be_a(Collie::AST::GrammarFile)
      expect(ast.declarations).not_to be_empty
      expect(ast.rules).not_to be_empty

      # Check for parameterized rules
      param_rules = ast.rules.select { |r| r.is_a?(Collie::AST::ParameterizedRule) }
      expect(param_rules).not_to be_empty

      # Check for named references in symbols
      named_refs = ast.rules.flat_map(&:alternatives).flat_map(&:symbols).select(&:alias_name)
      expect(named_refs).not_to be_empty
    end
  end
end
