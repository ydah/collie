# frozen_string_literal: true

require_relative "../ast"

module Collie
  module Parser
    # Token representation
    class Token
      attr_accessor :type, :value, :location

      def initialize(type:, value:, location:)
        @type = type
        @value = value
        @location = location
      end

      def to_s
        "#{type}(#{value.inspect})"
      end
    end

    # Lexer for .y grammar files
    class Lexer
      KEYWORDS = %w[
        %token %type %left %right %nonassoc %prec %union %start
        %rule %inline %code %expect %define %param %parse-param
        %lex-param %initial-action %destructor %printer
      ].freeze

      def initialize(source, filename: "<input>")
        @source = source
        @filename = filename
        @pos = 0
        @line = 1
        @column = 1
        @tokens = []
      end

      def tokenize
        until eof?
          skip_whitespace
          break if eof?

          if current_char == "/" && peek_char == "/"
            skip_line_comment
          elsif current_char == "/" && peek_char == "*"
            skip_block_comment
          elsif current_char == "%" && peek_char == "{"
            @tokens << tokenize_prologue
          elsif current_char == "%" && peek_char == "}"
            advance(2)
            @tokens << make_token(:PROLOGUE_END, "%}")
          elsif current_char == "%" && peek_char == "%"
            advance(2)
            @tokens << make_token(:SECTION_SEPARATOR, "%%")
          elsif current_char == "%" && alpha?(peek_char)
            @tokens << tokenize_directive
          elsif current_char == "{"
            @tokens << tokenize_action
          elsif current_char == "'"
            @tokens << tokenize_char_literal
          elsif current_char == '"'
            @tokens << tokenize_string_literal
          elsif current_char == "|"
            advance
            @tokens << make_token(:PIPE, "|")
          elsif current_char == ":"
            advance
            @tokens << make_token(:COLON, ":")
          elsif current_char == ";"
            advance
            @tokens << make_token(:SEMICOLON, ";")
          elsif current_char == "("
            advance
            @tokens << make_token(:LPAREN, "(")
          elsif current_char == ")"
            advance
            @tokens << make_token(:RPAREN, ")")
          elsif current_char == "["
            advance
            @tokens << make_token(:LBRACKET, "[")
          elsif current_char == "]"
            advance
            @tokens << make_token(:RBRACKET, "]")
          elsif current_char == ","
            advance
            @tokens << make_token(:COMMA, ",")
          elsif current_char == "<"
            @tokens << tokenize_type_tag
          elsif alpha?(current_char) || current_char == "_"
            @tokens << tokenize_identifier
          else
            advance
          end
        end

        @tokens << make_token(:EOF, "")
        @tokens
      end

      private

      def eof?
        @pos >= @source.length
      end

      def current_char
        return nil if eof?

        @source[@pos]
      end

      def peek_char(offset = 1)
        return nil if @pos + offset >= @source.length

        @source[@pos + offset]
      end

      def advance(count = 1)
        count.times do
          break if eof?

          if @source[@pos] == "\n"
            @line += 1
            @column = 1
          else
            @column += 1
          end
          @pos += 1
        end
      end

      def skip_whitespace
        advance while !eof? && whitespace?(current_char)
      end

      def skip_line_comment
        advance(2) # skip //
        advance until eof? || current_char == "\n"
        advance unless eof? # skip \n
      end

      def skip_block_comment
        advance(2) # skip /*
        until eof?
          if current_char == "*" && peek_char == "/"
            advance(2)
            break
          end
          advance
        end
      end

      def tokenize_prologue
        start_line = @line
        start_column = @column
        advance(2) # skip %{

        buffer = +""
        until eof? || (current_char == "%" && peek_char == "}")
          buffer << current_char
          advance
        end

        Token.new(
          type: :PROLOGUE_START,
          value: buffer,
          location: make_location(start_line, start_column, buffer.length + 2)
        )
      end

      def tokenize_directive
        start_line = @line
        start_column = @column
        buffer = +""

        while !eof? && (alpha?(current_char) || current_char == "%" || current_char == "-")
          buffer << current_char
          advance
        end

        type = case buffer
               when "%token" then :TOKEN
               when "%type" then :TYPE
               when "%left" then :LEFT
               when "%right" then :RIGHT
               when "%nonassoc" then :NONASSOC
               when "%prec" then :PREC
               when "%union" then :UNION
               when "%start" then :START
               when "%rule" then :RULE
               when "%inline" then :INLINE
               else :DIRECTIVE
               end

        Token.new(
          type: type,
          value: buffer,
          location: make_location(start_line, start_column, buffer.length)
        )
      end

      def tokenize_action
        start_line = @line
        start_column = @column
        buffer = +""
        depth = 0

        loop do
          break if eof?

          if current_char == "{"
            depth += 1
          elsif current_char == "}"
            depth -= 1
            if depth.zero?
              buffer << current_char
              advance
              break
            end
          end

          buffer << current_char
          advance
        end

        Token.new(
          type: :ACTION,
          value: buffer,
          location: make_location(start_line, start_column, buffer.length)
        )
      end

      def tokenize_char_literal
        start_line = @line
        start_column = @column
        buffer = +""
        advance # skip opening '

        until eof? || current_char == "'"
          buffer << current_char
          if current_char == "\\"
            advance
            buffer << current_char unless eof?
          end
          advance
        end

        advance unless eof? # skip closing '

        Token.new(
          type: :CHAR,
          value: buffer,
          location: make_location(start_line, start_column, buffer.length + 2)
        )
      end

      def tokenize_string_literal
        start_line = @line
        start_column = @column
        buffer = +""
        advance # skip opening "

        until eof? || current_char == '"'
          buffer << current_char
          if current_char == "\\"
            advance
            buffer << current_char unless eof?
          end
          advance
        end

        advance unless eof? # skip closing "

        Token.new(
          type: :STRING,
          value: buffer,
          location: make_location(start_line, start_column, buffer.length + 2)
        )
      end

      def tokenize_type_tag
        start_line = @line
        start_column = @column
        buffer = +""
        advance # skip <

        until eof? || current_char == ">"
          buffer << current_char
          advance
        end

        advance unless eof? # skip >

        Token.new(
          type: :TYPE_TAG,
          value: buffer,
          location: make_location(start_line, start_column, buffer.length + 2)
        )
      end

      def tokenize_identifier
        start_line = @line
        start_column = @column
        buffer = +""

        while !eof? && (alnum?(current_char) || current_char == "_")
          buffer << current_char
          advance
        end

        Token.new(
          type: :IDENTIFIER,
          value: buffer,
          location: make_location(start_line, start_column, buffer.length)
        )
      end

      def make_token(type, value)
        Token.new(
          type: type,
          value: value,
          location: make_location(@line, @column, value.length)
        )
      end

      def make_location(line, column, length)
        AST::Location.new(
          file: @filename,
          line: line,
          column: column,
          length: length
        )
      end

      def whitespace?(char)
        char&.match?(/\s/)
      end

      def alpha?(char)
        char&.match?(/[a-zA-Z]/)
      end

      def alnum?(char)
        char&.match?(/[a-zA-Z0-9]/)
      end
    end
  end
end
