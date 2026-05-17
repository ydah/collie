# frozen_string_literal: true

module Collie
  module Formatter
    # Semantic signature for verifying that formatting preserved grammar structure.
    class Signature
      def self.build(ast)
        new.build(ast)
      end

      def build(ast)
        [
          :grammar,
          ast.prologue&.code,
          ast.declarations.map { |declaration| declaration_signature(declaration) },
          ast.rules.map { |rule| rule_signature(rule) },
          ast.epilogue&.code
        ]
      end

      private

      def declaration_signature(declaration)
        case declaration
        when AST::TokenDeclaration
          [:token, declaration.type_tag, declaration.names]
        when AST::TypeDeclaration
          [:type, declaration.type_tag, declaration.names]
        when AST::PrecedenceDeclaration
          [:precedence, declaration.associativity, declaration.tokens]
        when AST::StartDeclaration
          [:start, declaration.symbol]
        when AST::UnionDeclaration
          [:union, declaration.body]
        when AST::UnknownDeclaration
          [:unknown, declaration.source]
        when AST::ParameterizedRule, AST::InlineRule
          rule_signature(declaration)
        else
          [declaration.class.name]
        end
      end

      def rule_signature(rule)
        [
          rule.is_a?(AST::InlineRule) ? :inline_rule : :rule,
          rule.is_a?(AST::InlineRule) ? rule.rule : rule.name,
          rule.respond_to?(:parameters) ? rule.parameters : [],
          rule.alternatives.map { |alternative| alternative_signature(alternative) }
        ]
      end

      def alternative_signature(alternative)
        [
          alternative.symbols.map { |symbol| symbol_signature(symbol) },
          alternative.action&.code,
          alternative.prec,
          alternative.explicit_empty
        ]
      end

      def symbol_signature(symbol)
        [
          symbol.name,
          symbol.kind,
          symbol.alias_name,
          Array(symbol.arguments).map { |argument| symbol_signature(argument) }
        ]
      end
    end
  end
end
