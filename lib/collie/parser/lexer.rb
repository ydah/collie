# frozen_string_literal: true

require_relative "../ast"

module Collie
  module Parser
    # Token representation
    class Token
      attr_accessor :type, :value, :location, :raw_value

      def initialize(type:, value:, location:, raw_value: nil)
        @type = type
        @value = value
        @location = location
        @raw_value = raw_value
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
        %lex-param %initial-action %destructor %printer %empty
      ].freeze

      def initialize(source, filename: "<input>")
        @source = source
        @filename = filename
        @pos = 0
        @line = 1
        @column = 1
        @tokens = []
        @section_separator_count = 0
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
            @tokens << tokenize_section_separator
            if @section_separator_count == 2
              epilogue = tokenize_epilogue
              @tokens << epilogue if epilogue
              break
            end
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
               when "%empty" then :EMPTY
               else
                 return tokenize_unknown_declaration(start_line, start_column, buffer)
               end

        Token.new(
          type: type,
          value: buffer,
          location: make_location(start_line, start_column, buffer.length)
        )
      end

      def tokenize_section_separator
        start_line = @line
        start_column = @column
        advance(2)
        @section_separator_count += 1

        Token.new(
          type: :SECTION_SEPARATOR,
          value: "%%",
          location: make_location(start_line, start_column, 2)
        )
      end

      def tokenize_epilogue
        consume_single_line_break
        return nil if eof?

        start_line = @line
        start_column = @column
        buffer = @source[@pos..]
        advance(buffer.length)

        Token.new(
          type: :EPILOGUE,
          value: buffer,
          location: make_location(start_line, start_column, buffer.length)
        )
      end

      def consume_single_line_break
        if current_char == "\r" && peek_char == "\n"
          advance(2)
        elsif current_char == "\n"
          advance
        end
      end

      def tokenize_unknown_declaration(start_line, start_column, directive)
        buffer = +directive

        append_unknown_declaration_content(buffer)

        Token.new(
          type: :UNKNOWN_DECLARATION,
          value: buffer.rstrip,
          location: make_location(start_line, start_column, buffer.length)
        )
      end

      def append_unknown_declaration_content(buffer)
        action_depth = 0

        until eof?
          break if action_depth.zero? && current_char == "\n"

          if action_depth.positive? && (current_char == '"' || current_char == "'")
            append_quoted_action_content(buffer, current_char)
            next
          elsif action_depth.positive? && current_char == "/" && peek_char == "/"
            append_line_comment_action_content(buffer)
            next
          elsif action_depth.positive? && current_char == "/" && peek_char == "*"
            append_block_comment_action_content(buffer)
            next
          elsif current_char == "{"
            action_depth += 1
          elsif current_char == "}" && action_depth.positive?
            action_depth -= 1
          end

          buffer << current_char
          advance
        end
      end

      def tokenize_action
        start_line = @line
        start_column = @column
        buffer = +""
        depth = 0

        loop do
          break if eof?

          if current_char == '"' || current_char == "'"
            append_quoted_action_content(buffer, current_char)
            next
          elsif current_char == "/" && peek_char == "/"
            append_line_comment_action_content(buffer)
            next
          elsif current_char == "/" && peek_char == "*"
            append_block_comment_action_content(buffer)
            next
          elsif current_char == "{"
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
        start_pos = @pos
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
        raw_value = @source[start_pos...@pos]

        Token.new(
          type: :CHAR,
          value: buffer,
          raw_value: raw_value,
          location: make_location(start_line, start_column, raw_value.length)
        )
      end

      def tokenize_string_literal
        start_pos = @pos
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
        raw_value = @source[start_pos...@pos]

        Token.new(
          type: :STRING,
          value: buffer,
          raw_value: raw_value,
          location: make_location(start_line, start_column, raw_value.length)
        )
      end

      def append_quoted_action_content(buffer, quote)
        buffer << current_char
        advance

        until eof?
          buffer << current_char

          if current_char == "\\"
            advance
            next if eof?

            buffer << current_char
          elsif current_char == quote
            advance
            break
          end

          advance
        end
      end

      def append_line_comment_action_content(buffer)
        buffer << current_char
        advance
        buffer << current_char
        advance

        until eof? || current_char == "\n"
          buffer << current_char
          advance
        end
      end

      def append_block_comment_action_content(buffer)
        buffer << current_char
        advance
        buffer << current_char
        advance

        until eof?
          if current_char == "*" && peek_char == "/"
            buffer << current_char
            advance
            buffer << current_char
            advance
            break
          end

          buffer << current_char
          advance
        end
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
