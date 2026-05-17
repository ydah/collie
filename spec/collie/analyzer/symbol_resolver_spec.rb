# frozen_string_literal: true

require "spec_helper"

RSpec.describe Collie::Analyzer::SymbolResolver do
  def parse_grammar(source)
    lexer = Collie::Parser::Lexer.new(source)
    tokens = lexer.tokenize
    parser = Collie::Parser::Parser.new(tokens)
    parser.parse
  end

  it "resolves lowercase declared tokens as terminals" do
    ast = parse_grammar(<<~GRAMMAR)
      %token lower
      %%
      expr
          : lower
          ;
      %%
    GRAMMAR
    table = Collie::Analyzer::SymbolTable.new
    table.add_token("lower")
    table.add_nonterminal("expr")

    described_class.resolve(ast, table)

    expect(ast.rules.first.alternatives.first.symbols.first).to be_terminal
  end

  it "resolves uppercase declared nonterminals as nonterminals" do
    ast = parse_grammar(<<~GRAMMAR)
      %%
      Start
          : Item
          ;
      Item
          : VALUE
          ;
      %%
    GRAMMAR
    table = Collie::Analyzer::SymbolTable.new
    table.add_nonterminal("Start")
    table.add_nonterminal("Item")

    described_class.resolve(ast, table)

    expect(ast.rules.first.alternatives.first.symbols.first).to be_nonterminal
  end
end
