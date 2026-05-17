# frozen_string_literal: true

require "thor"

module Collie
  # Command-line interface
  class CLI < Thor
    PARSE_ERROR_RULE = Class.new do
      class << self
        def rule_name = "ParseError"
        def description = "Reports grammar parse errors"
        def severity = :error
        def autocorrectable = false
      end
    end

    def self.exit_on_failure?
      true
    end

    map %w[--version -v] => :version

    desc "lint FILES", "Lint grammar files"
    option :config, type: :string, desc: "Config file path"
    option :format, type: :string, default: "text", enum: %w[text json github sarif], desc: "Output format"
    option :autocorrect, type: :boolean, aliases: "-a", desc: "Auto-fix offenses"
    option :only, type: :array, desc: "Run only specified rules"
    option :except, type: :array, desc: "Exclude specified rules"
    option :fail_level, type: :string, default: "error", enum: %w[error warning convention info],
                        desc: "Minimum severity that exits with failure"
    option :stdin, type: :boolean, desc: "Read source from standard input"
    option :stdin_filename, type: :string, default: "<stdin>", desc: "Filename to use for standard input"
    def lint(*files)
      config = Config.new(options[:config])
      Linter::Registry.load_rules

      return lint_stdin(config) if options[:stdin]

      files = resolve_files(files, config)
      if files.empty?
        say "No files matched", :red
        exit 1
      end

      all_offenses = []
      failed = false

      files.each do |file|
        unless File.exist?(file)
          say "File not found: #{file}", :red
          failed = true
          next
        end

        offenses = lint_file(file, config)
        all_offenses.concat(offenses)
      end

      reporter = create_reporter(options[:format])
      puts reporter.report(all_offenses)

      exit 1 if failed || fail_level_reached?(all_offenses)
    end

    desc "fmt FILES", "Format grammar files"
    option :check, type: :boolean, desc: "Check only, don't modify"
    option :diff, type: :boolean, desc: "Show diff"
    option :config, type: :string, desc: "Config file path"
    option :stdin, type: :boolean, desc: "Read source from standard input"
    option :stdin_filename, type: :string, default: "<stdin>", desc: "Filename to use for standard input"
    def fmt(*files)
      config = Config.new(options[:config])
      formatter = Formatter::Formatter.new(Formatter::Options.new(config.formatter_options))

      return fmt_stdin(formatter) if options[:stdin]

      files = resolve_files(files, config)
      if files.empty?
        say "No files matched", :red
        exit 1
      end

      failed = false
      changed = false

      files.each do |file|
        unless File.exist?(file)
          say "File not found: #{file}", :red
          failed = true
          next
        end

        result = format_file(file, formatter, check: options[:check], diff: options[:diff])
        failed = true if result == :failed
        changed = true if result == :changed
      end

      exit 1 if failed || changed
    end

    desc "rules", "List all available rules"
    option :config, type: :string, desc: "Config file path"
    option :format, type: :string, default: "text", enum: %w[text json]
    def rules
      config = Config.new(options[:config])
      Linter::Registry.load_rules

      if options[:format] == "json"
        output = Linter::Registry.all.map do |rule|
          rule_config = config.rule_config(rule.rule_name)
          {
            name: rule.rule_name,
            description: rule.description,
            enabled: config.rule_enabled?(rule.rule_name),
            severity: configured_rule_severity(rule, rule_config),
            autocorrectable: rule.autocorrectable
          }
        end
        puts JSON.pretty_generate(output)
      else
        say "Available lint rules:", :bold
        Linter::Registry.all.each do |rule|
          rule_config = config.rule_config(rule.rule_name)
          severity = configured_rule_severity(rule, rule_config)
          severity_color = severity_color(severity)
          autocorrect = rule.autocorrectable ? " [autocorrectable]" : ""
          enabled = config.rule_enabled?(rule.rule_name) ? "" : " [disabled]"
          say "  #{rule.rule_name} (#{set_color(severity, severity_color)})#{autocorrect}#{enabled}"
          say "    #{rule.description}", :dim
        end
      end
    end

    desc "init", "Generate default .collie.yml"
    def init
      return if File.exist?(".collie.yml") && !yes?(".collie.yml already exists. Overwrite? (y/n)")

      Config.generate_default
      say "Generated .collie.yml", :green
    end

    desc "version", "Show version"
    def version
      puts "Collie version #{Collie::VERSION}"
    end

    private

    def lint_stdin(config)
      source = $stdin.read
      offenses = lint_source(source, filename: options[:stdin_filename], config: config)

      reporter = create_reporter(options[:format])
      puts reporter.report(offenses)

      exit 1 if fail_level_reached?(offenses)
    end

    def lint_file(file, config)
      source = File.read(file)
      lint_source(source, filename: file, config: config, autocorrect_path: file)
    end

    def lint_source(source, filename:, config:, autocorrect_path: nil)
      ast = parse_source(source, filename: filename)

      symbol_table = build_symbol_table(ast)
      context = { symbol_table: symbol_table, source: source, file: filename }

      offenses = run_lint_rules(ast, context, config)
      apply_autocorrect(autocorrect_path, source, context, offenses) if autocorrect_path && options[:autocorrect]

      offenses
    rescue Error => e
      [parse_error_offense(filename, e.message)]
    end

    def build_symbol_table(ast)
      symbol_table = Analyzer::SymbolTable.new
      ast.declarations.each do |decl|
        case decl
        when AST::TokenDeclaration
          decl.names.each do |name|
            symbol_table.add_token(name, type_tag: decl.type_tag, location: decl.location)
          rescue Error
            # Ignore duplicate declarations here, they'll be caught by lint rules
          end
        when AST::ParameterizedRule
          symbol_table.add_nonterminal(decl.name, location: decl.location)
        when AST::InlineRule
          symbol_table.add_nonterminal(decl.rule, location: decl.location)
        end
      end

      ast.rules.each do |rule|
        symbol_table.add_nonterminal(rule.name, location: rule.location)
      end

      symbol_table
    end

    def run_lint_rules(ast, context, config)
      enabled_rules = Linter::Registry.enabled_rules(config)
      enabled_rules = filter_rules(enabled_rules) if options[:only] || options[:except]

      offenses = []
      enabled_rules.each do |rule_class|
        rule = rule_class.new(config.rule_config(rule_class.rule_name))
        offenses.concat(rule.check(ast, context))
      end

      offenses
    end

    def apply_autocorrect(file, source, context, offenses)
      autocorrectable_offenses = offenses.select(&:autocorrectable?)
      return if autocorrectable_offenses.empty?

      autocorrectable_offenses.each do |offense|
        offense.autocorrect&.call
      end

      return unless context[:source] != source

      File.write(file, context[:source])
      say "Auto-corrected #{autocorrectable_offenses.size} offense(s) in #{file}", :green
    end

    def fmt_stdin(formatter)
      source = $stdin.read
      formatted = format_source(source, formatter, filename: options[:stdin_filename])
      exit 1 unless formatted

      if options[:check]
        if source == formatted
          say "#{options[:stdin_filename]}: OK", :green
        else
          say "#{options[:stdin_filename]}: needs formatting", :yellow
          show_diff(source, formatted) if options[:diff]
          exit 1
        end
      elsif options[:diff]
        if source == formatted
          say "#{options[:stdin_filename]}: OK", :green
        else
          say "#{options[:stdin_filename]}: needs formatting", :yellow
          show_diff(source, formatted)
          exit 1
        end
      else
        puts formatted
      end
    end

    def format_file(file, formatter, check: false, diff: false)
      source = File.read(file)
      formatted = format_source(source, formatter, filename: file)
      return :failed unless formatted

      if check
        if source == formatted
          say "#{file}: OK", :green
          :ok
        else
          say "#{file}: needs formatting", :yellow
          show_diff(source, formatted) if diff
          :changed
        end
      elsif diff
        if source == formatted
          say "#{file}: OK", :green
          :ok
        else
          say "#{file}: needs formatting", :yellow
          show_diff(source, formatted)
          :changed
        end
      else
        File.write(file, formatted)
        say "Formatted #{file}", :green
        :ok
      end
    rescue Error => e
      say "Error formatting #{file}: #{e.message}", :red
      :failed
    end

    def format_source(source, formatter, filename:)
      ast = parse_source(source, filename: filename)
      formatted = formatter.format(ast)
      parse_source(formatted, filename: filename)
      formatted
    rescue Error => e
      say "Error formatting #{filename}: #{e.message}", :red
      nil
    end

    def parse_source(source, filename:)
      lexer = Parser::Lexer.new(source, filename: filename)
      tokens = lexer.tokenize
      parser = Parser::Parser.new(tokens)
      parser.parse
    end

    def parse_error_offense(file, message)
      Linter::Offense.new(
        rule: PARSE_ERROR_RULE,
        location: parse_error_location(file, message),
        message: message,
        severity: :error
      )
    end

    def parse_error_location(file, message)
      match = message.match(/:(\d+):(\d+)\b/)
      line = match ? match[1].to_i : 1
      column = match ? match[2].to_i : 1

      AST::Location.new(file: file, line: line, column: column)
    end

    def filter_rules(rules)
      filtered = rules

      only = rule_filter(:only)
      except = rule_filter(:except)

      filtered = filtered.select { |r| only.include?(r.rule_name) } if only.any?

      filtered = filtered.reject { |r| except.include?(r.rule_name) } if except.any?

      filtered
    end

    def rule_filter(option_name)
      Array(options[option_name]).flat_map { |value| value.split(",") }.map(&:strip).reject(&:empty?)
    end

    def resolve_files(files, config)
      targets = files.empty? ? config.included_patterns : files
      resolved = targets.flat_map { |target| expand_target(target) }.uniq
      return resolved unless files.empty?

      resolved.reject { |file| excluded?(file, config.excluded_patterns) }
    end

    def expand_target(target)
      return Dir.glob(target).select { |path| File.file?(path) } if glob_pattern?(target)

      [target]
    end

    def glob_pattern?(target)
      target.match?(/[*?\[\]{}]/)
    end

    def excluded?(file, patterns)
      patterns.any? { |pattern| File.fnmatch?(pattern, file, File::FNM_PATHNAME | File::FNM_EXTGLOB) }
    end

    def fail_level_reached?(offenses)
      threshold = severity_rank(options[:fail_level].to_sym)
      offenses.any? { |offense| severity_rank(offense.severity) >= threshold }
    end

    def severity_rank(severity)
      {
        info: 0,
        convention: 1,
        warning: 2,
        error: 3
      }.fetch(severity, 3)
    end

    def create_reporter(format)
      case format
      when "json"
        Reporter::Json.new
      when "github"
        Reporter::Github.new
      when "sarif"
        Reporter::Sarif.new
      else
        Reporter::Text.new
      end
    end

    def configured_rule_severity(rule, rule_config)
      configured = rule_config["severity"] || rule_config[:severity]
      return rule.severity unless configured

      configured.to_sym
    end

    def severity_color(severity)
      case severity
      when :error then :red
      when :warning then :yellow
      when :convention then :blue
      when :info then :cyan
      else :white
      end
    end

    def show_diff(original, formatted)
      puts unified_diff(original, formatted)
    end

    def unified_diff(original, formatted)
      original_lines = original.lines
      formatted_lines = formatted.lines
      prefix = common_prefix_length(original_lines, formatted_lines)
      suffix = common_suffix_length(original_lines, formatted_lines, prefix)

      original_start = [prefix - 3, 0].max
      formatted_start = [prefix - 3, 0].max
      original_end = [original_lines.length - suffix + 3, original_lines.length].min
      formatted_end = [formatted_lines.length - suffix + 3, formatted_lines.length].min

      output = [
        "--- original",
        "+++ formatted",
        "@@ -#{hunk_range(original_start, original_end)} +#{hunk_range(formatted_start, formatted_end)} @@"
      ]

      original_lines[original_start...prefix].each { |line| output << " #{line.chomp}" }
      original_lines[prefix...(original_lines.length - suffix)].each { |line| output << "-#{line.chomp}" }
      formatted_lines[prefix...(formatted_lines.length - suffix)].each { |line| output << "+#{line.chomp}" }
      formatted_lines[(formatted_lines.length - suffix)...formatted_end].each { |line| output << " #{line.chomp}" }

      output.join("\n")
    end

    def common_prefix_length(left, right)
      index = 0
      index += 1 while index < left.length && index < right.length && left[index] == right[index]
      index
    end

    def common_suffix_length(left, right, prefix_length)
      left_index = left.length - 1
      right_index = right.length - 1
      count = 0

      while left_index >= prefix_length && right_index >= prefix_length && left[left_index] == right[right_index]
        count += 1
        left_index -= 1
        right_index -= 1
      end

      count
    end

    def hunk_range(start_index, end_index)
      length = end_index - start_index
      length == 1 ? (start_index + 1).to_s : "#{start_index + 1},#{length}"
    end
  end
end
