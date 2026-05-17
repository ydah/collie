# frozen_string_literal: true

module Collie
  module Formatter
    # Formatter for .y grammar files
    class Formatter
      def initialize(options = Options.new)
        @options = options
      end

      def format(ast)
        output = []

        # Prologue
        output << format_prologue(ast.prologue) if ast.prologue
        append_blank_lines(output) if ast.prologue

        # Declarations
        output << format_declarations(ast.declarations) unless ast.declarations.empty?
        append_blank_lines(output) unless ast.declarations.empty?

        # Section separator
        output << "%%"
        append_blank_lines(output)

        # Rules
        output << format_rules(ast.rules) unless ast.rules.empty?

        # Epilogue
        if ast.epilogue
          append_blank_lines(output)
          output << "%%"
          append_blank_lines(output)
          output << ast.epilogue.code
        end

        output.pop while output.last == ""
        output.join("\n")
      end

      private

      def format_prologue(prologue)
        ["%{", prologue.code, "%}"].join("\n")
      end

      def format_declarations(declarations)
        output = []
        index = 0

        while index < declarations.length
          declaration = declarations[index]
          declarations_group = consecutive_declarations(declarations, index, declaration.class)
          output << format_declaration_group(declarations_group)
          output << ""
          index += declarations_group.length
        end

        output.pop while output.last == ""
        output.join("\n")
      end

      def consecutive_declarations(declarations, start_index, declaration_class)
        declarations[start_index..].take_while { |declaration| declaration.is_a?(declaration_class) }
      end

      def format_declaration_group(declarations)
        case declarations.first
        when AST::TokenDeclaration
          format_token_declarations(declarations)
        when AST::TypeDeclaration
          format_type_declarations(declarations)
        when AST::PrecedenceDeclaration
          format_precedence_declarations(declarations)
        when AST::UnionDeclaration
          format_union_declarations(declarations)
        when AST::UnknownDeclaration
          format_unknown_declarations(declarations)
        when AST::StartDeclaration
          format_start_declarations(declarations)
        when AST::ParameterizedRule
          format_parameterized_rule_declarations(declarations)
        when AST::InlineRule
          format_inline_rule_declarations(declarations)
        end
      end

      def format_token_declarations(declarations)
        if @options.align_tokens
          format_aligned_tokens(declarations)
        else
          declarations.map { |decl| format_token_declaration(decl) }.join("\n")
        end
      end

      def format_aligned_tokens(declarations)
        max_tag_length = declarations.map { |d| d.type_tag ? d.type_tag.length + 2 : 0 }.max || 0
        declarations.map do |decl|
          tag = decl.type_tag ? "<#{decl.type_tag}>" : ""
          if tag.empty?
            "%token #{decl.names.join(' ')}"
          else
            "%token #{tag.ljust(max_tag_length)} #{decl.names.join(' ')}"
          end
        end.join("\n")
      end

      def format_token_declaration(decl)
        tag = decl.type_tag ? " <#{decl.type_tag}>" : ""
        "%token#{tag} #{decl.names.join(' ')}"
      end

      def format_type_declarations(declarations)
        declarations.map do |decl|
          tag = decl.type_tag ? " <#{decl.type_tag}>" : ""
          "%type#{tag} #{decl.names.join(' ')}"
        end.join("\n")
      end

      def format_precedence_declarations(declarations)
        directive_names = {
          left: "%left",
          right: "%right",
          nonassoc: "%nonassoc"
        }

        max_directive_length = directive_names.values.map(&:length).max

        declarations.map do |decl|
          directive = directive_names[decl.associativity]
          if @options.align_tokens
            "#{directive.ljust(max_directive_length)} #{decl.tokens.join(' ')}"
          else
            "#{directive} #{decl.tokens.join(' ')}"
          end
        end.join("\n")
      end

      def format_union_declarations(declarations)
        declarations.map do |decl|
          body = decl.body.to_s
          body.start_with?("{") ? "%union #{body}" : "%union {#{body}}"
        end.join("\n")
      end

      def format_unknown_declarations(declarations)
        declarations.map(&:source).join("\n")
      end

      def format_start_declarations(declarations)
        declarations.map { |decl| "%start #{decl.symbol}" }.join("\n")
      end

      def format_parameterized_rule_declarations(declarations)
        declarations.map do |decl|
          params = "(#{decl.parameters.join(', ')})"
          alternatives = decl.alternatives.map { |alt| format_alternative(alt) }.join(" | ")
          "%rule #{decl.name}#{params}: #{alternatives} ;"
        end.join("\n")
      end

      def format_inline_rule_declarations(declarations)
        declarations.map do |decl|
          output = "%inline #{decl.rule}"
          output += "(#{decl.parameters.join(', ')})" unless decl.parameters.empty?
          unless decl.alternatives.empty?
            alternatives = decl.alternatives.map { |alt| format_alternative(alt) }.join(" | ")
            separator = alternatives.start_with?(" |") ? "" : " "
            output += ":#{separator}#{alternatives} ;"
          end
          output
        end.join("\n")
      end

      def format_rules(rules)
        rules.map { |rule| format_rule(rule) }.join("\n\n")
      end

      def format_rule(rule)
        # Handle parameterized rules: rule_name(X, Y)
        rule_header = rule.name.to_s
        if rule.is_a?(AST::ParameterizedRule) && rule.parameters && !rule.parameters.empty?
          rule_header += "(#{rule.parameters.join(', ')})"
        end

        output = [rule_header]
        indent = @options.indent

        rule.alternatives.each_with_index do |alt, index|
          prefix = index.zero? ? "#{indent}:" : "#{indent}|"
          output << "#{prefix} #{format_alternative(alt)}"
        end

        output << "#{indent};"
        output.join("\n")
      end

      def format_alternative(alt)
        symbols_str = alt.explicit_empty ? (alt.empty_marker || "%empty") : alt.symbols.map { |sym| format_symbol(sym) }.join(" ")
        action_str = alt.action ? " #{alt.action.code}" : ""
        prec_str = alt.prec ? " %prec #{alt.prec}" : ""

        "#{symbols_str}#{prec_str}#{action_str}"
      end

      def format_symbol(symbol)
        result = symbol.name

        # Add named reference: symbol[name]
        result += "[#{symbol.alias_name}]" if symbol.alias_name

        # Add parameterized call arguments: symbol(arg1, arg2)
        if symbol.arguments && !symbol.arguments.empty?
          args_str = symbol.arguments.map { |arg| format_symbol(arg) }.join(", ")
          result += "(#{args_str})"
        end

        result
      end

      def append_blank_lines(output)
        @options.blank_lines_around_sections.times { output << "" }
      end
    end
  end
end
