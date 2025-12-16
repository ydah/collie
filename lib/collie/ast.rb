# frozen_string_literal: true

module Collie
  module AST
    # Location information for source code elements
    class Location
      attr_accessor :file, :line, :column, :length

      def initialize(file:, line:, column:, length: 0)
        @file = file
        @line = line
        @column = column
        @length = length
      end

      def to_s
        "#{file}:#{line}:#{column}"
      end
    end

    # Root node representing the entire grammar file
    class GrammarFile
      attr_accessor :prologue, :declarations, :rules, :epilogue, :location

      def initialize(prologue: nil, declarations: [], rules: [], epilogue: nil, location: nil)
        @prologue = prologue
        @declarations = declarations
        @rules = rules
        @epilogue = epilogue
        @location = location
      end
    end

    # Token declaration node (%token)
    class TokenDeclaration
      attr_accessor :names, :type_tag, :location

      def initialize(names:, type_tag: nil, location: nil)
        @names = names
        @type_tag = type_tag
        @location = location
      end
    end

    # Type declaration node (%type)
    class TypeDeclaration
      attr_accessor :type_tag, :names, :location

      def initialize(type_tag:, names:, location: nil)
        @type_tag = type_tag
        @names = names
        @location = location
      end
    end

    # Precedence declaration node (%left, %right, %nonassoc)
    class PrecedenceDeclaration
      attr_accessor :associativity, :tokens, :location

      def initialize(associativity:, tokens:, location: nil)
        @associativity = associativity # :left, :right, :nonassoc
        @tokens = tokens
        @location = location
      end
    end

    # Start symbol declaration node (%start)
    class StartDeclaration
      attr_accessor :symbol, :location

      def initialize(symbol:, location: nil)
        @symbol = symbol
        @location = location
      end
    end

    # Union declaration node (%union)
    class UnionDeclaration
      attr_accessor :body, :location

      def initialize(body:, location: nil)
        @body = body
        @location = location
      end
    end

    # Grammar rule node
    class Rule
      attr_accessor :name, :alternatives, :location

      def initialize(name:, alternatives: [], location: nil)
        @name = name
        @alternatives = alternatives
        @location = location
      end
    end

    # Alternative production for a rule
    class Alternative
      attr_accessor :symbols, :action, :prec, :location

      def initialize(symbols: [], action: nil, prec: nil, location: nil)
        @symbols = symbols
        @action = action
        @prec = prec
        @location = location
      end
    end

    # Symbol reference (terminal or nonterminal)
    class Symbol
      attr_accessor :name, :kind, :alias_name, :arguments, :location

      def initialize(name:, kind:, alias_name: nil, arguments: nil, location: nil)
        @name = name
        @kind = kind # :terminal, :nonterminal
        @alias_name = alias_name
        @arguments = arguments # For parameterized rule calls like list(expr)
        @location = location
      end

      def terminal?
        kind == :terminal
      end

      def nonterminal?
        kind == :nonterminal
      end
    end

    # Action code block
    class Action
      attr_accessor :code, :location

      def initialize(code:, location: nil)
        @code = code
        @location = location
      end
    end

    # Lrama extension: Parameterized rule
    class ParameterizedRule
      attr_accessor :name, :parameters, :alternatives, :location

      def initialize(name:, parameters:, alternatives:, location: nil)
        @name = name
        @parameters = parameters
        @alternatives = alternatives
        @location = location
      end
    end

    # Lrama extension: Inline rule
    class InlineRule
      attr_accessor :rule, :location

      def initialize(rule:, location: nil)
        @rule = rule
        @location = location
      end
    end

    # Prologue section (code before first %%)
    class Prologue
      attr_accessor :code, :location

      def initialize(code:, location: nil)
        @code = code
        @location = location
      end
    end

    # Epilogue section (code after second %%)
    class Epilogue
      attr_accessor :code, :location

      def initialize(code:, location: nil)
        @code = code
        @location = location
      end
    end
  end
end
