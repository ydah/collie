# frozen_string_literal: true

require "spec_helper"

RSpec.describe Collie::Parser::Lexer do
  describe "#tokenize" do
    it "tokenizes token declarations" do
      source = "%token IDENTIFIER NUMBER"
      lexer = described_class.new(source)
      tokens = lexer.tokenize

      expect(tokens[0].type).to eq(:TOKEN)
      expect(tokens[1].type).to eq(:IDENTIFIER)
      expect(tokens[1].value).to eq("IDENTIFIER")
      expect(tokens[2].type).to eq(:IDENTIFIER)
      expect(tokens[2].value).to eq("NUMBER")
    end

    it "tokenizes section separators" do
      source = "%%"
      lexer = described_class.new(source)
      tokens = lexer.tokenize

      expect(tokens[0].type).to eq(:SECTION_SEPARATOR)
    end

    it "tokenizes type tags" do
      source = "%token <node> IDENTIFIER"
      lexer = described_class.new(source)
      tokens = lexer.tokenize

      expect(tokens[1].type).to eq(:TYPE_TAG)
      expect(tokens[1].value).to eq("node")
    end

    it "tokenizes string literals" do
      source = '"++"'
      lexer = described_class.new(source)
      tokens = lexer.tokenize

      expect(tokens[0].type).to eq(:STRING)
      expect(tokens[0].value).to eq("++")
    end
  end
end
