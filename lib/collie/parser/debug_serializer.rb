# frozen_string_literal: true

require_relative "../ast"

module Collie
  module Parser
    # Serializes parser internals for CLI debug commands.
    module DebugSerializer
      class << self
        def token(token)
          {
            type: token.type,
            value: token.value,
            raw_value: token.raw_value,
            location: location(token.location)
          }
        end

        def ast(node)
          return nil unless node

          case node
          when AST::GrammarFile
            grammar_file(node)
          when AST::Prologue, AST::Epilogue
            code_node(node)
          when AST::TokenDeclaration
            token_declaration(node)
          when AST::TypeDeclaration
            type_declaration(node)
          when AST::PrecedenceDeclaration
            precedence_declaration(node)
          when AST::StartDeclaration
            start_declaration(node)
          when AST::UnionDeclaration
            union_declaration(node)
          when AST::UnknownDeclaration
            unknown_declaration(node)
          when AST::Rule
            rule(node)
          when AST::ParameterizedRule
            parameterized_rule(node)
          when AST::InlineRule
            inline_rule(node)
          when AST::Alternative
            alternative(node)
          when AST::Symbol
            symbol(node)
          when AST::Action
            action(node)
          else
            { type: node.class.name }
          end
        end

        private

        def grammar_file(node)
          {
            type: "GrammarFile",
            prologue: ast(node.prologue),
            declarations: node.declarations.map { |declaration| ast(declaration) },
            rules: node.rules.map { |rule| ast(rule) },
            epilogue: ast(node.epilogue),
            location: location(node.location)
          }
        end

        def code_node(node)
          {
            type: node_type(node),
            code: node.code,
            location: location(node.location)
          }
        end

        def token_declaration(node)
          {
            type: "TokenDeclaration",
            names: node.names,
            type_tag: node.type_tag,
            location: location(node.location)
          }
        end

        def type_declaration(node)
          {
            type: "TypeDeclaration",
            names: node.names,
            type_tag: node.type_tag,
            location: location(node.location)
          }
        end

        def precedence_declaration(node)
          {
            type: "PrecedenceDeclaration",
            associativity: node.associativity,
            tokens: node.tokens,
            location: location(node.location)
          }
        end

        def start_declaration(node)
          {
            type: "StartDeclaration",
            symbol: node.symbol,
            location: location(node.location)
          }
        end

        def union_declaration(node)
          {
            type: "UnionDeclaration",
            body: node.body,
            location: location(node.location)
          }
        end

        def unknown_declaration(node)
          {
            type: "UnknownDeclaration",
            source: node.source,
            location: location(node.location)
          }
        end

        def rule(node)
          {
            type: "Rule",
            name: node.name,
            alternatives: node.alternatives.map { |alternative| ast(alternative) },
            location: location(node.location)
          }
        end

        def parameterized_rule(node)
          {
            type: "ParameterizedRule",
            name: node.name,
            parameters: node.parameters,
            alternatives: node.alternatives.map { |alternative| ast(alternative) },
            location: location(node.location)
          }
        end

        def inline_rule(node)
          {
            type: "InlineRule",
            rule: node.rule,
            parameters: node.parameters,
            alternatives: node.alternatives.map { |alternative| ast(alternative) },
            location: location(node.location)
          }
        end

        def alternative(node)
          {
            type: "Alternative",
            symbols: node.symbols.map { |symbol| ast(symbol) },
            action: ast(node.action),
            prec: node.prec,
            explicit_empty: node.explicit_empty,
            empty_marker: node.empty_marker,
            location: location(node.location)
          }
        end

        def symbol(node)
          {
            type: "Symbol",
            name: node.name,
            kind: node.kind,
            alias_name: node.alias_name,
            arguments: node.arguments&.map { |argument| ast(argument) },
            location: location(node.location)
          }
        end

        def action(node)
          {
            type: "Action",
            code: node.code,
            location: location(node.location)
          }
        end

        def node_type(node)
          node.class.name.split("::").last
        end

        def location(location)
          return nil unless location

          {
            file: location.file,
            line: location.line,
            column: location.column,
            length: location.length
          }
        end
      end
    end
  end
end
