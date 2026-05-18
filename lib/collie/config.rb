# frozen_string_literal: true

require "yaml"

module Collie
  # Configuration management
  class Config
    DEFAULT_CONFIG = {
      "rules" => {},
      "formatter" => {
        "indent_size" => 2,
        "align_tokens" => true,
        "align_alternatives" => true,
        "blank_lines_around_sections" => 1,
        "max_line_length" => 120
      },
      "include" => ["**/*.y"],
      "exclude" => ["vendor/**/*", "tmp/**/*"]
    }.freeze

    PROFILE_OVERRIDES = {
      "default" => {},
      "lrama" => {
        "rules" => {
          "LeftRecursion" => { "enabled" => false },
          "FactorizableRules" => { "enabled" => false },
          "RightRecursion" => { "severity" => "warning" }
        }
      },
      "bison" => {
        "rules" => {
          "LeftRecursion" => { "enabled" => false },
          "FactorizableRules" => { "enabled" => false },
          "RightRecursion" => { "severity" => "warning" }
        }
      },
      "strict" => {
        "formatter" => {
          "max_line_length" => 100
        },
        "rules" => {
          "AmbiguousPrecedence" => { "severity" => "warning" },
          "ConsistentTagNaming" => { "severity" => "warning" },
          "EmptyAction" => { "severity" => "warning" },
          "FactorizableRules" => { "severity" => "warning" },
          "LongRule" => { "severity" => "warning" },
          "NonterminalNaming" => { "severity" => "warning" },
          "PrecImprovement" => { "severity" => "warning" },
          "RedundantEpsilon" => { "severity" => "warning" },
          "TokenNaming" => { "severity" => "warning" },
          "TrailingWhitespace" => { "severity" => "warning" }
        }
      },
      "minimal" => {
        "rules" => {
          "AmbiguousPrecedence" => { "enabled" => false },
          "ConsistentTagNaming" => { "enabled" => false },
          "EmptyAction" => { "enabled" => false },
          "FactorizableRules" => { "enabled" => false },
          "LeftRecursion" => { "enabled" => false },
          "LongRule" => { "enabled" => false },
          "NonterminalNaming" => { "enabled" => false },
          "PrecImprovement" => { "enabled" => false },
          "RedundantEpsilon" => { "enabled" => false },
          "RightRecursion" => { "enabled" => false },
          "TokenNaming" => { "enabled" => false },
          "TrailingWhitespace" => { "enabled" => false },
          "UnreachableRule" => { "enabled" => false },
          "UnusedNonterminal" => { "enabled" => false },
          "UnusedToken" => { "enabled" => false }
        }
      }
    }.freeze

    PROFILE_NAMES = PROFILE_OVERRIDES.keys.freeze

    attr_reader :config

    def initialize(config_path = nil)
      @config = load_config(config_path)
    end

    def rule_enabled?(rule_name)
      rule_config = @config.dig("rules", rule_name)
      return true if rule_config.nil? # Enabled by default

      rule_config.is_a?(Hash) ? rule_config.fetch("enabled", true) : rule_config
    end

    def rule_config(rule_name)
      @config.dig("rules", rule_name) || {}
    end

    def formatter_options
      @config["formatter"] || DEFAULT_CONFIG["formatter"]
    end

    def included_patterns
      @config["include"] || DEFAULT_CONFIG["include"]
    end

    def excluded_patterns
      @config["exclude"] || DEFAULT_CONFIG["exclude"]
    end

    def self.default
      new
    end

    def self.generate_default(path = ".collie.yml", profile: "default")
      File.write(path, profile_config(profile).to_yaml)
    end

    def self.profile_config(profile)
      profile_name = profile.to_s
      raise Error, "Unknown config profile: #{profile}" unless PROFILE_OVERRIDES.key?(profile_name)

      deep_merge(DEFAULT_CONFIG, PROFILE_OVERRIDES.fetch(profile_name))
    end

    def self.schema
      Schema.to_h
    end

    def self.deep_merge(hash1, hash2)
      hash1.merge(hash2) do |_key, old_val, new_val|
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          deep_merge(old_val, new_val)
        else
          new_val
        end
      end
    end

    private

    def load_config(config_path)
      config = DEFAULT_CONFIG.dup
      if config_path
        raise Error, "Config file not found: #{config_path}" unless File.exist?(config_path)

        path = config_path
      else
        path = ".collie.yml" if File.exist?(".collie.yml")
      end
      return config unless path

      user_config = load_yaml_config(path)

      if user_config["inherit_from"]
        parent_path = File.expand_path(user_config["inherit_from"], File.dirname(path))
        raise Error, "Inherited config file not found: #{parent_path}" unless File.exist?(parent_path)

        config = deep_merge(config, load_yaml_config(parent_path))
      end

      deep_merge(config, user_config)
    end

    def load_yaml_config(path)
      loaded = YAML.safe_load(File.read(path), aliases: true) || {}
      raise Error, "Config file must contain a YAML mapping: #{path}" unless loaded.is_a?(Hash)

      loaded
    rescue Psych::SyntaxError => e
      raise Error, "Invalid config file #{path}: #{e.message}"
    end

    def deep_merge(hash1, hash2)
      self.class.deep_merge(hash1, hash2)
    end
  end
end

require_relative "config/schema"
