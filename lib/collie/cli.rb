# frozen_string_literal: true

require "thor"

module Collie
  # Command-line interface
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    map %w[--version -v] => :version

    desc "lint FILES", "Lint grammar files"
    option :config, type: :string, desc: "Config file path"
    option :format, type: :string, default: "text", enum: %w[text json github], desc: "Output format"
    option :autocorrect, type: :boolean, aliases: "-a", desc: "Auto-fix offenses"
    option :only, type: :array, desc: "Run only specified rules"
    option :except, type: :array, desc: "Exclude specified rules"
    option :fail_level, type: :string, default: "error", enum: %w[error warning convention info],
                        desc: "Minimum severity that exits with failure"
    def lint(*files)
      config = Config.new(options[:config])
      Linter::Registry.load_rules

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
        unless offenses
          failed = true
          next
        end

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
    def fmt(*files)
      config = Config.new(options[:config])
      files = resolve_files(files, config)
      if files.empty?
        say "No files matched", :red
        exit 1
      end

      formatter = Formatter::Formatter.new(Formatter::Options.new(config.formatter_options))
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
    option :format, type: :string, default: "text", enum: %w[text json]
    def rules
      Linter::Registry.load_rules

      if options[:format] == "json"
        output = Linter::Registry.all.map do |rule|
          {
            name: rule.rule_name,
            description: rule.description,
            severity: rule.severity,
            autocorrectable: rule.autocorrectable
          }
        end
        puts JSON.pretty_generate(output)
      else
        say "Available lint rules:", :bold
        Linter::Registry.all.each do |rule|
          severity_color = severity_color(rule.severity)
          autocorrect = rule.autocorrectable ? " [autocorrectable]" : ""
          say "  #{rule.rule_name} (#{set_color(rule.severity, severity_color)})#{autocorrect}"
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

    def lint_file(file, config)
      source = File.read(file)
      lexer = Parser::Lexer.new(source, filename: file)
      tokens = lexer.tokenize
      parser = Parser::Parser.new(tokens)
      ast = parser.parse

      symbol_table = build_symbol_table(ast)
      context = { symbol_table: symbol_table, source: source, file: file }

      offenses = run_lint_rules(ast, context, config)
      apply_autocorrect(file, source, context, offenses) if options[:autocorrect]

      offenses
    rescue Error => e
      say "Error parsing #{file}: #{e.message}", :red
      nil
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

    def format_file(file, formatter, check: false, diff: false)
      source = File.read(file)
      lexer = Parser::Lexer.new(source, filename: file)
      tokens = lexer.tokenize
      parser = Parser::Parser.new(tokens)
      ast = parser.parse

      formatted = formatter.format(ast)

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
      else
        Reporter::Text.new
      end
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
      require "tempfile"

      Tempfile.create(["original", ".y"]) do |orig|
        Tempfile.create(["formatted", ".y"]) do |fmt|
          orig.write(original)
          orig.flush
          fmt.write(formatted)
          fmt.flush

          system("diff", "-u", orig.path, fmt.path)
        end
      end
    end
  end
end
