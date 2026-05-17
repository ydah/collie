# frozen_string_literal: true

require "spec_helper"

Collie::Linter::Registry.load_rules

RSpec.describe Collie::Linter::Rules::EmptyAction do
  let(:rule) { described_class.new({}) }

  def create_grammar_with_action(action_code)
    symbols = [
      Collie::AST::Symbol.new(name: "NUMBER", kind: :terminal, location: nil)
    ]
    action = Collie::AST::Action.new(code: action_code, location: nil)
    alternative = Collie::AST::Alternative.new(symbols: symbols, action: action, location: nil)
    grammar_rule = Collie::AST::Rule.new(name: "expr", alternatives: [alternative], location: nil)

    Collie::AST::GrammarFile.new(rules: [grammar_rule], declarations: [])
  end

  def parse_grammar(source)
    lexer = Collie::Parser::Lexer.new(source, filename: "test.y")
    tokens = lexer.tokenize
    parser = Collie::Parser::Parser.new(tokens)
    parser.parse
  end

  describe "#check" do
    it "detects empty action" do
      grammar = create_grammar_with_action("")

      offenses = rule.check(grammar)
      expect(offenses).not_to be_empty
      expect(offenses.first.message).to include("Empty action block")
    end

    it "detects whitespace-only action" do
      grammar = create_grammar_with_action("   \n  \t  ")

      offenses = rule.check(grammar)
      expect(offenses).not_to be_empty
    end

    it "detects brace-wrapped empty action" do
      grammar = create_grammar_with_action("{   }")

      offenses = rule.check(grammar)
      expect(offenses).not_to be_empty
    end

    it "allows action with code" do
      grammar = create_grammar_with_action("$$ = $1;")

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "allows alternative without action" do
      symbols = [
        Collie::AST::Symbol.new(name: "NUMBER", kind: :terminal, location: nil)
      ]
      alternative = Collie::AST::Alternative.new(symbols: symbols, action: nil, location: nil)
      grammar_rule = Collie::AST::Rule.new(name: "expr", alternatives: [alternative], location: nil)
      grammar = Collie::AST::GrammarFile.new(rules: [grammar_rule], declarations: [])

      offenses = rule.check(grammar)
      expect(offenses).to be_empty
    end

    it "supports autocorrect" do
      grammar = create_grammar_with_action("")
      offenses = rule.check(grammar)

      expect(offenses.first.autocorrectable?).to be true
    end

    it "autocorrects source-backed empty actions" do
      source = <<~GRAMMAR
        %%
        expr
            : NUMBER {   }
            ;
        %%
      GRAMMAR

      grammar = parse_grammar(source)
      context = { source: source.dup, file: "test.y" }
      offenses = rule.check(grammar, context)

      offenses.first.autocorrect.call

      expect(context[:source]).not_to include("{   }")
      expect(grammar.rules.first.alternatives.first.action).to be_nil
    end

    it "detects empty actions in inline declarations" do
      source = <<~GRAMMAR
        %inline opt(X): X {   } ;
        %%
        %%
      GRAMMAR

      grammar = parse_grammar(source)
      offenses = rule.check(grammar)

      expect(offenses.map(&:message)).to include("Empty action block can be removed")
    end
  end
end
