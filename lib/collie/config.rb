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

    def self.generate_default(path = ".collie.yml")
      File.write(path, DEFAULT_CONFIG.to_yaml)
    end

    private

    def load_config(config_path)
      config = DEFAULT_CONFIG.dup

      if config_path && File.exist?(config_path)
        user_config = YAML.load_file(config_path)
        config = deep_merge(config, user_config)

        # Handle inheritance
        if user_config["inherit_from"]
          parent_path = File.expand_path(user_config["inherit_from"], File.dirname(config_path))
          parent_config = YAML.load_file(parent_path) if File.exist?(parent_path)
          config = deep_merge(parent_config, config) if parent_config
        end
      elsif File.exist?(".collie.yml")
        user_config = YAML.load_file(".collie.yml")
        config = deep_merge(config, user_config)
      end

      config
    end

    def deep_merge(hash1, hash2)
      hash1.merge(hash2) do |_key, old_val, new_val|
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          deep_merge(old_val, new_val)
        else
          new_val
        end
      end
    end
  end
end
