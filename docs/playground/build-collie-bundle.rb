#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

OUTPUT_FILE = Pathname.new(__dir__) / "collie-bundle.rb"
LIB_DIR = Pathname.new(__dir__) / ".." / ".." / "lib"

files = [
  "collie/version.rb",
  "collie/ast.rb",
  "collie/parser/lexer.rb",
  "collie/parser/parser.rb",
  "collie/analyzer/symbol_table.rb",
  "collie/analyzer/reachability.rb",
  "collie/analyzer/recursion.rb",
  "collie/analyzer/conflict.rb",
  "collie/linter/base.rb",
  "collie/linter/registry.rb",
  "collie/linter/rules/duplicate_token.rb",
  "collie/linter/rules/undefined_symbol.rb",
  "collie/linter/rules/unreachable_rule.rb",
  "collie/linter/rules/circular_reference.rb",
  "collie/linter/rules/missing_start_symbol.rb",
  "collie/linter/rules/unused_nonterminal.rb",
  "collie/linter/rules/unused_token.rb",
  "collie/linter/rules/left_recursion.rb",
  "collie/linter/rules/right_recursion.rb",
  "collie/linter/rules/ambiguous_precedence.rb",
  "collie/linter/rules/token_naming.rb",
  "collie/linter/rules/nonterminal_naming.rb",
  "collie/linter/rules/consistent_tag_naming.rb",
  "collie/linter/rules/trailing_whitespace.rb",
  "collie/linter/rules/empty_action.rb",
  "collie/linter/rules/long_rule.rb",
  "collie/linter/rules/factorizable_rules.rb",
  "collie/linter/rules/redundant_epsilon.rb",
  "collie/linter/rules/prec_improvement.rb",
  "collie/formatter/options.rb",
  "collie/formatter/formatter.rb",
  "collie/reporter/text.rb",
  "collie/reporter/json.rb",
  "collie/reporter/github.rb",
  "collie/config.rb",
  "collie.rb"
]

output = []
output << "# frozen_string_literal: true"
output << ""
output << "# Collie Bundle for Ruby.wasm Playground"
output << "# Auto-generated - DO NOT EDIT"
output << "# Generated at: #{Time.now}"
output << ""

files.each do |file_path|
  full_path = LIB_DIR / file_path
  unless full_path.exist?
    warn "Warning: #{file_path} not found, skipping"
    next
  end

  output << "# === #{file_path} ==="
  content = File.read(full_path)

  content = content.gsub(/^# frozen_string_literal: true\n/, "")
  content = content.gsub(/^require ['"]collie.*$\n/, "")
  content = content.gsub(/^require_relative .*$\n/, "")
  content = content.gsub(/^require ["']pastel["']\n/, "")
  content = content.gsub(/^require ["']thor["']\n/, "")
  content = content.gsub(/^require ["']tty-table["']\n/, "")

  content = content.gsub(
    /begin\s+require ["']pastel["']\s+PASTEL_AVAILABLE = true\s+rescue LoadError\s+PASTEL_AVAILABLE = false\s+end/m,
    "PASTEL_AVAILABLE = false"
  )

  output << content
  output << ""
end

File.write(OUTPUT_FILE, output.join("\n"))
puts "Bundle created: #{OUTPUT_FILE}"
puts "Size: #{File.size(OUTPUT_FILE)} bytes (#{(File.size(OUTPUT_FILE) / 1024.0).round(2)} KB)"
puts "Files bundled: #{files.size}"
