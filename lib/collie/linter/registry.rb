# frozen_string_literal: true

module Collie
  module Linter
    # Registry for lint rules
    class Registry
      @rules = {}

      class << self
        def register(rule_class)
          @rules[rule_class.rule_name] = rule_class if rule_class.rule_name
        end

        def all
          @rules.values
        end

        def find(name)
          @rules[name]
        end

        def enabled_rules(config)
          all.select { |rule| config.rule_enabled?(rule.rule_name) }
        end

        # Auto-load all rules from rules/ directory
        def load_rules
          rules_path = File.join(__dir__, "rules", "*.rb")
          Dir[rules_path].each { |f| require f }
        end
      end
    end
  end
end
