# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Lint integration" do
  let(:fixture_path) { File.expand_path("../fixtures/simple.y", __dir__) }

  before do
    Collie::Linter::Registry.load_rules
  end

  it "lints a simple grammar file" do
    source = File.read(fixture_path)
    lexer = Collie::Parser::Lexer.new(source, filename: fixture_path)
    tokens = lexer.tokenize
    parser = Collie::Parser::Parser.new(tokens)
    ast = parser.parse

    expect(ast).to be_a(Collie::AST::GrammarFile)
    expect(ast.rules).not_to be_empty
    expect(ast.declarations).not_to be_empty
  end

  it "detects no offenses in valid grammar" do
    source = File.read(fixture_path)
    lexer = Collie::Parser::Lexer.new(source, filename: fixture_path)
    tokens = lexer.tokenize
    parser = Collie::Parser::Parser.new(tokens)
    ast = parser.parse

    # Build symbol table
    symbol_table = Collie::Analyzer::SymbolTable.new
    ast.declarations.each do |decl|
      case decl
      when Collie::AST::TokenDeclaration
        decl.names.each do |name|
          symbol_table.add_token(name, type_tag: decl.type_tag, location: decl.location)
        rescue Collie::Error
          # Ignore duplicates
        end
      end
    end

    ast.rules.each do |rule|
      symbol_table.add_nonterminal(rule.name, location: rule.location)
    end

    context = { symbol_table: symbol_table }

    # Run undefined symbol check
    rule = Collie::Linter::Rules::UndefinedSymbol.new
    offenses = rule.check(ast, context)

    expect(offenses).to be_empty
  end
end
