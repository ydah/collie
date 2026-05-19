# frozen_string_literal: true

require "spec_helper"

RSpec.describe Collie::Playground do
  def parse_response(json)
    JSON.parse(json)
  end

  describe ".lint" do
    it "returns diagnostics with a summary" do
      source = <<~YACC
        %token NUMBER
        %token UNUSED

        %%

        expr: NUMBER ;

        %%
      YACC

      response = parse_response(described_class.lint("source" => source))

      expect(response["ok"]).to be true
      expect(response["summary"]["total"]).to be >= 1
      expect(response["diagnostics"].map { |diagnostic| diagnostic["rule_name"] }).to include("UnusedToken")
    end

    it "reports parse errors at the parser location" do
      source = <<~YACC
        %token NUMBER

        expr: NUMBER ;
      YACC

      response = parse_response(described_class.lint("source" => source))

      expect(response["ok"]).to be false
      expect(response["diagnostics"].first["rule_name"]).to eq("ParseError")
      expect(response["diagnostics"].first["location"]["line"]).to eq(4)
    end
  end

  describe ".format" do
    it "returns formatted source" do
      source = <<~YACC
        %token NUMBER

        %%
        expr: NUMBER ;
        %%
      YACC

      response = parse_response(described_class.format("source" => source))

      expect(response["ok"]).to be true
      expect(response["formatted"]).to include("expr")
    end
  end

  describe ".autocorrect" do
    it "applies autocorrectable offenses" do
      source = "%token NUMBER  \n\n%%\nexpr: NUMBER ;\n%%\n"

      response = parse_response(described_class.autocorrect("source" => source))

      expect(response["ok"]).to be true
      expect(response["applied"]).to be >= 1
      expect(response["source"]).not_to include("  \n")
    end
  end

  describe ".rules" do
    it "returns registered playground rules" do
      response = parse_response(described_class.rules)
      rule_names = response["rules"].map { |rule| rule["name"] }

      expect(rule_names).to include("SymbolConflict", "UnusedToken", "TrailingWhitespace")
    end
  end
end
