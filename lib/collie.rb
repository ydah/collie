# frozen_string_literal: true

require_relative "collie/version"
require_relative "collie/cli"
require_relative "collie/config"
require_relative "collie/ast"
require_relative "collie/parser/lexer"
require_relative "collie/parser/parser"
require_relative "collie/analyzer/symbol_table"
require_relative "collie/analyzer/reachability"
require_relative "collie/analyzer/recursion"
require_relative "collie/analyzer/conflict"
require_relative "collie/linter/base"
require_relative "collie/linter/registry"
require_relative "collie/formatter/formatter"
require_relative "collie/formatter/options"
require_relative "collie/reporter/text"
require_relative "collie/reporter/json"
require_relative "collie/reporter/github"

# Collie is a linter and formatter for Lrama Style BNF grammar files (.y files).
#
# @example Basic usage
#   require 'collie'
#
#   # Parse a grammar file
#   parser = Collie::Parser::Parser.new(File.read('grammar.y'))
#   ast = parser.parse
#
#   # Run linter
#   config = Collie::Config.new
#   linter = Collie::Linter.new(config)
#   offenses = linter.lint(ast)
#
#   # Format the grammar
#   formatter = Collie::Formatter::Formatter.new(config.formatter_options)
#   puts formatter.format(ast)
#
# @see https://github.com/ruby/lrama Lrama parser generator
module Collie
  # Base error class for all Collie errors
  class Error < StandardError; end

  class << self
    # Returns the root directory of the Collie gem
    #
    # @return [String] absolute path to the gem root directory
    def root
      File.expand_path("..", __dir__)
    end
  end
end
