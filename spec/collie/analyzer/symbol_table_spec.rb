# frozen_string_literal: true

require "spec_helper"

RSpec.describe Collie::Analyzer::SymbolTable do
  let(:table) { described_class.new }

  describe "#add_token" do
    it "adds a token" do
      table.add_token("NUMBER")
      expect(table.token?("NUMBER")).to be true
    end

    it "adds a token with type tag" do
      location = Collie::AST::Location.new(file: "test.y", line: 1, column: 1)
      table.add_token("NUMBER", type_tag: "int", location: location)

      expect(table.tokens["NUMBER"][:type_tag]).to eq("int")
      expect(table.tokens["NUMBER"][:location]).to eq(location)
    end

    it "raises error for duplicate tokens" do
      table.add_token("NUMBER")
      expect { table.add_token("NUMBER") }.to raise_error(Collie::Error)
    end
  end

  describe "#add_nonterminal" do
    it "adds a nonterminal" do
      table.add_nonterminal("expr")
      expect(table.nonterminal?("expr")).to be true
    end

    it "does not add duplicate nonterminals" do
      table.add_nonterminal("expr")
      table.add_nonterminal("expr")
      expect(table.nonterminals.keys.count("expr")).to eq(1)
    end
  end

  describe "#use_token" do
    it "increments usage count" do
      table.add_token("NUMBER")
      expect(table.tokens["NUMBER"][:usage_count]).to eq(0)

      table.use_token("NUMBER")
      expect(table.tokens["NUMBER"][:usage_count]).to eq(1)

      table.use_token("NUMBER")
      expect(table.tokens["NUMBER"][:usage_count]).to eq(2)
    end
  end

  describe "#use_nonterminal" do
    it "increments usage count" do
      table.add_nonterminal("expr")
      expect(table.nonterminals["expr"][:usage_count]).to eq(0)

      table.use_nonterminal("expr")
      expect(table.nonterminals["expr"][:usage_count]).to eq(1)
    end
  end

  describe "#unused_tokens" do
    it "returns tokens with zero usage" do
      table.add_token("USED")
      table.add_token("UNUSED")

      table.use_token("USED")

      expect(table.unused_tokens).to eq(["UNUSED"])
    end
  end

  describe "#unused_nonterminals" do
    it "returns nonterminals with zero usage" do
      table.add_nonterminal("used")
      table.add_nonterminal("unused")

      table.use_nonterminal("used")

      expect(table.unused_nonterminals).to eq(["unused"])
    end
  end

  describe "#declared?" do
    it "returns true for declared symbols" do
      table.add_token("NUMBER")
      table.add_nonterminal("expr")

      expect(table.declared?("NUMBER")).to be true
      expect(table.declared?("expr")).to be true
      expect(table.declared?("UNDEFINED")).to be false
    end
  end

  describe "#duplicate_symbols" do
    it "returns symbols that are both token and nonterminal" do
      table.add_token("FOO")
      table.add_nonterminal("FOO")

      expect(table.duplicate_symbols).to eq(["FOO"])
    end
  end
end
