# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Collie::Config do
  describe ".default" do
    it "returns a config with default values" do
      config = described_class.default
      expect(config.formatter_options["indent_size"]).to eq(2)
    end
  end

  describe "#rule_enabled?" do
    it "returns true for enabled rules" do
      config = described_class.default
      expect(config.rule_enabled?("DuplicateToken")).to be true
    end

    it "returns true by default when rule not in config" do
      config = described_class.default
      expect(config.rule_enabled?("NonExistentRule")).to be true
    end

    it "respects explicit enabled: false" do
      Tempfile.create(["config", ".yml"]) do |f|
        f.write(<<~YAML)
          rules:
            DuplicateToken:
              enabled: false
        YAML
        f.flush

        config = described_class.new(f.path)
        expect(config.rule_enabled?("DuplicateToken")).to be false
      end
    end
  end

  describe "#rule_config" do
    it "returns empty hash for unconfigured rules" do
      config = described_class.default
      expect(config.rule_config("SomeRule")).to eq({})
    end

    it "returns rule configuration" do
      Tempfile.create(["config", ".yml"]) do |f|
        f.write(<<~YAML)
          rules:
            TokenNaming:
              enabled: true
              pattern: '^[A-Z]+$'
        YAML
        f.flush

        config = described_class.new(f.path)
        rule_config = config.rule_config("TokenNaming")
        expect(rule_config["pattern"]).to eq("^[A-Z]+$")
      end
    end
  end

  describe "#formatter_options" do
    it "returns default formatter options" do
      config = described_class.default
      opts = config.formatter_options

      expect(opts["indent_size"]).to eq(2)
      expect(opts["align_tokens"]).to be true
    end

    it "allows custom formatter options" do
      Tempfile.create(["config", ".yml"]) do |f|
        f.write(<<~YAML)
          formatter:
            indent_size: 4
            align_tokens: false
        YAML
        f.flush

        config = described_class.new(f.path)
        opts = config.formatter_options

        expect(opts["indent_size"]).to eq(4)
        expect(opts["align_tokens"]).to be false
      end
    end
  end

  describe "#included_patterns" do
    it "returns default patterns" do
      config = described_class.default
      expect(config.included_patterns).to eq(["**/*.y"])
    end
  end

  describe "#excluded_patterns" do
    it "returns default excluded patterns" do
      config = described_class.default
      expect(config.excluded_patterns).to include("vendor/**/*")
    end
  end

  describe "configuration inheritance" do
    it "inherits from parent config" do
      Tempfile.create(["base", ".yml"]) do |base|
        Tempfile.create(["child", ".yml"]) do |child|
          base.write(<<~YAML)
            rules:
              DuplicateToken:
                enabled: false
          YAML
          base.flush

          child.write(<<~YAML)
            inherit_from: #{base.path}
            rules:
              TokenNaming:
                enabled: false
          YAML
          child.flush

          config = described_class.new(child.path)
          expect(config.rule_enabled?("DuplicateToken")).to be false
          expect(config.rule_enabled?("TokenNaming")).to be false
        end
      end
    end
  end
end
