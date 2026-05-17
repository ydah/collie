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

    it "tokenizes %empty alternatives" do
      source = "%empty"
      lexer = described_class.new(source)
      tokens = lexer.tokenize

      expect(tokens[0].type).to eq(:EMPTY)
    end

    it "tokenizes empty comments as explicit empty alternatives" do
      source = "/* empty */"
      lexer = described_class.new(source)
      tokens = lexer.tokenize

      expect(tokens[0].type).to eq(:EMPTY)
      expect(tokens[0].value).to eq("/* empty */")
    end

    it "keeps unknown directive lines as a single token" do
      source = "%define api.value.type {variant}\n%%"
      lexer = described_class.new(source)
      tokens = lexer.tokenize

      expect(tokens[0].type).to eq(:UNKNOWN_DECLARATION)
      expect(tokens[0].value).to eq("%define api.value.type {variant}")
    end

    it "keeps unknown directive action blocks as a single token" do
      source = "%code {\n  puts \"}\"\n}\n%%"
      lexer = described_class.new(source)
      tokens = lexer.tokenize

      expect(tokens[0].type).to eq(:UNKNOWN_DECLARATION)
      expect(tokens[0].value).to eq("%code {\n  puts \"}\"\n}")
    end

    it "keeps epilogue as raw source after the second section separator" do
      source = "%%\n%%\nint main() {\n  return 0;\n}\n"
      lexer = described_class.new(source)
      tokens = lexer.tokenize

      expect(tokens[2].type).to eq(:EPILOGUE)
      expect(tokens[2].value).to eq("int main() {\n  return 0;\n}\n")
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
      expect(tokens[0].raw_value).to eq('"++"')
    end

    it "keeps braces inside action strings from closing the action" do
      source = '{ puts "}"; }'
      lexer = described_class.new(source)
      tokens = lexer.tokenize

      expect(tokens[0].type).to eq(:ACTION)
      expect(tokens[0].value).to eq('{ puts "}"; }')
    end

    it "keeps braces inside action comments from closing the action" do
      source = "{ /* } */ puts 1; }"
      lexer = described_class.new(source)
      tokens = lexer.tokenize

      expect(tokens[0].type).to eq(:ACTION)
      expect(tokens[0].value).to eq("{ /* } */ puts 1; }")
    end
  end
end
