#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

BUNDLE_PATH = File.expand_path("collie-bundle.rb", __dir__)

abort "Missing playground bundle. Run docs/playground/build-collie-bundle.rb first." unless File.exist?(BUNDLE_PATH)

TOPLEVEL_BINDING.eval(File.read(BUNDLE_PATH))

def parse_response(json)
  JSON.parse(json)
end

def assert(condition, message)
  abort "Smoke test failed: #{message}" unless condition
end

rules_response = parse_response(Collie::Playground.rules)
rule_names = rules_response.fetch("rules").map { |rule| rule.fetch("name") }
assert(rule_names.include?("SymbolConflict"), "SymbolConflict rule is not bundled")
assert(rule_names.include?("UnusedToken"), "UnusedToken rule is not bundled")

lint_source = <<~YACC
  %token expr

  %%

  expr: expr ;

  %%
YACC

lint_response = parse_response(Collie::Playground.lint("source" => lint_source))
diagnostic_rules = lint_response.fetch("diagnostics").map { |diagnostic| diagnostic.fetch("rule_name") }
assert(diagnostic_rules.include?("SymbolConflict"), "lint did not report SymbolConflict")

format_source = <<~YACC
  %token NUMBER

  %%
  expr: NUMBER ;
  %%
YACC

format_response = parse_response(Collie::Playground.format("source" => format_source))
assert(format_response.fetch("ok"), "format failed")
assert(format_response.fetch("formatted").include?("expr"), "format output is missing rule content")

fix_source = "%token NUMBER  \n\n%%\nexpr: NUMBER ;\n%%\n"
fix_response = parse_response(Collie::Playground.autocorrect("source" => fix_source))
assert(fix_response.fetch("ok"), "autocorrect failed")
assert(fix_response.fetch("applied").positive?, "autocorrect did not apply any fixes")

puts "Playground smoke test passed"
