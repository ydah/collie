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

        # Declarations
        output << format_declarations(ast.declarations) unless ast.declarations.empty?

        # Section separator
        output << ""
        output << "%%"
        output << ""

        # Rules
        output << format_rules(ast.rules)

        # Epilogue
        if ast.epilogue
          output << ""
          output << "%%"
          output << ""
          output << ast.epilogue.code
        end

        output.join("\n")
      end

      private

      def format_prologue(prologue)
        ["%{", prologue.code, "%}"].join("\n")
      end

      def format_declarations(declarations)
        grouped = declarations.group_by(&:class)
        output = []

        # Format token declarations
        if grouped[AST::TokenDeclaration]
          output << format_token_declarations(grouped[AST::TokenDeclaration])
          output << ""
        end

        # Format type declarations
        if grouped[AST::TypeDeclaration]
          output << format_type_declarations(grouped[AST::TypeDeclaration])
          output << ""
        end

        # Format precedence declarations
        if grouped[AST::PrecedenceDeclaration]
          output << format_precedence_declarations(grouped[AST::PrecedenceDeclaration])
          output << ""
        end

        # Format start declaration
        if grouped[AST::StartDeclaration]
          start_decl = grouped[AST::StartDeclaration].first
          output << "%start #{start_decl.symbol}"
          output << ""
        end

        # Format %rule declarations (Lrama extension)
        if grouped[AST::ParameterizedRule]
          output << format_parameterized_rule_declarations(grouped[AST::ParameterizedRule])
          output << ""
        end

        # Format %inline declarations (Lrama extension)
        if grouped[AST::InlineRule]
          output << format_inline_rule_declarations(grouped[AST::InlineRule])
          output << ""
        end

        output.join("\n")
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
          "%token #{tag.ljust(max_tag_length)} #{decl.names.join(' ')}"
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

      def format_parameterized_rule_declarations(declarations)
        declarations.map do |decl|
          params = "(#{decl.parameters.join(', ')})"
          alternatives = decl.alternatives.map { |alt| format_alternative(alt) }.join(" | ")
          "%rule #{decl.name}#{params}: #{alternatives} ;"
        end.join("\n")
      end

      def format_inline_rule_declarations(declarations)
        declarations.map do |decl|
          "%inline #{decl.rule}"
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

        rule.alternatives.each_with_index do |alt, index|
          prefix = index.zero? ? "    :" : "    |"
          output << "#{prefix} #{format_alternative(alt)}"
        end

        output << "    ;"
        output.join("\n")
      end

      def format_alternative(alt)
        symbols_str = alt.symbols.map { |sym| format_symbol(sym) }.join(" ")
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
    end
  end
end
