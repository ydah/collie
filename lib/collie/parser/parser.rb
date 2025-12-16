# frozen_string_literal: true

require_relative "../ast"

module Collie
  module Parser
    # Parser for .y grammar files
    class Parser
      def initialize(tokens)
        @tokens = tokens
        @pos = 0
      end

      def parse
        prologue = parse_prologue
        declarations = parse_declarations
        expect(:SECTION_SEPARATOR)
        rules = parse_rules
        epilogue = parse_epilogue

        AST::GrammarFile.new(
          prologue: prologue,
          declarations: declarations,
          rules: rules,
          epilogue: epilogue,
          location: current_token.location
        )
      end

      private

      def current_token
        @tokens[@pos] || @tokens.last
      end

      def peek_token(offset = 1)
        @tokens[@pos + offset] || @tokens.last
      end

      def advance
        @pos += 1 unless @pos >= @tokens.length
      end

      def expect(type)
        unless current_token.type == type
          raise Error, "Expected #{type} but got #{current_token.type} at #{current_token.location}"
        end

        token = current_token
        advance
        token
      end

      def match?(type)
        current_token.type == type
      end

      def parse_prologue
        return nil unless match?(:PROLOGUE_START)

        token = current_token
        advance
        AST::Prologue.new(code: token.value, location: token.location)
      end

      def parse_declarations
        declarations = []

        while !match?(:SECTION_SEPARATOR) && !match?(:EOF)
          case current_token.type
          when :TOKEN
            declarations << parse_token_declaration
          when :TYPE
            declarations << parse_type_declaration
          when :LEFT, :RIGHT, :NONASSOC
            declarations << parse_precedence_declaration
          when :START
            declarations << parse_start_declaration
          when :UNION
            declarations << parse_union_declaration
          when :RULE
            # %rule for Lrama extensions (handled inline)
            advance
            declarations << parse_lrama_rule_declaration
          when :INLINE
            # %inline for Lrama extensions
            advance
            declarations << parse_inline_declaration
          else
            advance # Skip unknown declarations for now
          end
        end

        declarations
      end

      def parse_lrama_rule_declaration
        # %rule followed by rule definition
        # This is similar to parse_rule but in declaration section
        name_token = expect(:IDENTIFIER)

        parameters = []
        if match?(:LPAREN)
          advance
          parameters = parse_parameter_list
          expect(:RPAREN)
        end

        expect(:COLON)

        alternatives = []
        alternatives << parse_alternative

        while match?(:PIPE)
          advance
          alternatives << parse_alternative
        end

        expect(:SEMICOLON) if match?(:SEMICOLON)

        AST::ParameterizedRule.new(
          name: name_token.value,
          parameters: parameters,
          alternatives: alternatives,
          location: name_token.location
        )
      end

      def parse_inline_declaration
        # %inline followed by rule name
        rule_name = expect(:IDENTIFIER).value

        AST::InlineRule.new(
          rule: rule_name,
          location: current_token.location
        )
      end

      def parse_token_declaration
        token = expect(:TOKEN)
        type_tag = nil
        names = []

        if match?(:TYPE_TAG)
          type_tag = current_token.value
          advance
        end

        while match?(:IDENTIFIER) || match?(:STRING) || match?(:CHAR)
          names << current_token.value
          advance
        end

        AST::TokenDeclaration.new(
          names: names,
          type_tag: type_tag,
          location: token.location
        )
      end

      def parse_type_declaration
        token = expect(:TYPE)
        type_tag = nil

        if match?(:TYPE_TAG)
          type_tag = current_token.value
          advance
        end

        names = []
        while match?(:IDENTIFIER)
          names << current_token.value
          advance
        end

        AST::TypeDeclaration.new(
          type_tag: type_tag,
          names: names,
          location: token.location
        )
      end

      def parse_precedence_declaration
        token = current_token
        associativity = case token.type
                        when :LEFT then :left
                        when :RIGHT then :right
                        when :NONASSOC then :nonassoc
                        end
        advance

        tokens = []
        while match?(:IDENTIFIER) || match?(:STRING) || match?(:CHAR)
          tokens << current_token.value
          advance
        end

        AST::PrecedenceDeclaration.new(
          associativity: associativity,
          tokens: tokens,
          location: token.location
        )
      end

      def parse_start_declaration
        token = expect(:START)
        symbol = expect(:IDENTIFIER).value

        AST::StartDeclaration.new(
          symbol: symbol,
          location: token.location
        )
      end

      def parse_union_declaration
        token = expect(:UNION)
        body = +""

        if match?(:ACTION)
          body = current_token.value
          advance
        end

        AST::UnionDeclaration.new(
          body: body,
          location: token.location
        )
      end

      def parse_rules
        rules = []

        until match?(:SECTION_SEPARATOR) || match?(:EOF)
          if match?(:IDENTIFIER)
            rules << parse_rule
          else
            advance
          end
        end

        rules
      end

      def parse_rule
        name_token = expect(:IDENTIFIER)

        # Check for parameterized rule: rule_name(param1, param2)
        parameters = []
        if match?(:LPAREN)
          advance
          parameters = parse_parameter_list
          expect(:RPAREN)
        end

        expect(:COLON)

        alternatives = []
        alternatives << parse_alternative

        while match?(:PIPE)
          advance
          alternatives << parse_alternative
        end

        expect(:SEMICOLON) if match?(:SEMICOLON)

        # Return ParameterizedRule if parameters exist
        if parameters.empty?
          AST::Rule.new(
            name: name_token.value,
            alternatives: alternatives,
            location: name_token.location
          )
        else
          AST::ParameterizedRule.new(
            name: name_token.value,
            parameters: parameters,
            alternatives: alternatives,
            location: name_token.location
          )
        end
      end

      def parse_parameter_list
        params = []
        params << expect(:IDENTIFIER).value

        while match?(:COMMA)
          advance
          params << expect(:IDENTIFIER).value
        end

        params
      end

      def parse_argument_list
        # Parse arguments for parameterized rule calls
        # Arguments are symbols (terminals or nonterminals)
        args = []

        if match?(:IDENTIFIER) || match?(:STRING) || match?(:CHAR)
          symbol_token = current_token
          kind = if symbol_token.value.match?(/^[A-Z]/) || match?(:STRING) || match?(:CHAR)
                   :terminal
                 else
                   :nonterminal
                 end
          advance

          args << AST::Symbol.new(
            name: symbol_token.value,
            kind: kind,
            location: symbol_token.location
          )

          while match?(:COMMA)
            advance
            symbol_token = current_token
            kind = if symbol_token.value.match?(/^[A-Z]/) || match?(:STRING) || match?(:CHAR)
                     :terminal
                   else
                     :nonterminal
                   end
            advance

            args << AST::Symbol.new(
              name: symbol_token.value,
              kind: kind,
              location: symbol_token.location
            )
          end
        end

        args
      end

      def parse_alternative
        symbols = []
        action = nil
        prec = nil
        start_location = current_token.location

        until match?(:PIPE) || match?(:SEMICOLON) || match?(:ACTION) ||
              match?(:SECTION_SEPARATOR) || match?(:EOF)
          if match?(:PREC)
            advance
            prec = current_token.value
            advance
          elsif match?(:IDENTIFIER) || match?(:STRING) || match?(:CHAR)
            symbol_token = current_token
            kind = if symbol_token.value.match?(/^[A-Z]/) || match?(:STRING) || match?(:CHAR)
                     :terminal
                   else
                     :nonterminal
                   end
            advance

            # Check for named reference: symbol[name] or parameterized call: symbol(args)
            alias_name = nil
            arguments = nil

            if match?(:LBRACKET)
              advance
              alias_name = expect(:IDENTIFIER).value
              expect(:RBRACKET)
            elsif match?(:LPAREN)
              # Parameterized rule call: list(expr)
              advance
              arguments = parse_argument_list
              expect(:RPAREN)
            end

            symbols << AST::Symbol.new(
              name: symbol_token.value,
              kind: kind,
              alias_name: alias_name,
              arguments: arguments,
              location: symbol_token.location
            )
          else
            break
          end
        end

        if match?(:ACTION)
          action = AST::Action.new(
            code: current_token.value,
            location: current_token.location
          )
          advance
        end

        AST::Alternative.new(
          symbols: symbols,
          action: action,
          prec: prec,
          location: symbols.first&.location || start_location
        )
      end

      def parse_epilogue
        return nil unless match?(:SECTION_SEPARATOR)

        advance
        code = +""

        until match?(:EOF)
          code << current_token.value
          advance
        end

        AST::Epilogue.new(code: code, location: current_token.location) unless code.empty?
      end
    end
  end
end
