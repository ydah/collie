# frozen_string_literal: true

require "spec_helper"

RSpec.describe Collie::Formatter::Formatter do
  let(:formatter) { described_class.new }

  def parse_grammar(source)
    lexer = Collie::Parser::Lexer.new(source)
    tokens = lexer.tokenize
    parser = Collie::Parser::Parser.new(tokens)
    parser.parse
  end

  describe "#format" do
    it "honors YAML-style formatter option keys" do
      options = Collie::Formatter::Options.new(
        "indent_size" => 4,
        "align_tokens" => false
      )

      expect(options.indent).to eq(" " * 4)
      expect(options.align_tokens).to be false
    end

    it "uses configured indentation for rule bodies" do
      source = <<~GRAMMAR
        %%
        expr
            : NUMBER
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      formatter = described_class.new(Collie::Formatter::Options.new("indent_size" => 4))
      output = formatter.format(ast)

      expect(output).to include("    : NUMBER")
    end

    it "honors disabled alternative alignment" do
      source = <<~GRAMMAR
        %%
        expr
            : NUMBER
            | IDENTIFIER
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      formatter = described_class.new(Collie::Formatter::Options.new("align_alternatives" => false))
      output = formatter.format(ast)

      expect(output).to include("expr\n: NUMBER\n| IDENTIFIER\n;")
    end

    it "wraps long declarations using max_line_length" do
      source = <<~GRAMMAR
        %token FIRST SECOND THIRD FOURTH FIFTH
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      formatter = described_class.new(Collie::Formatter::Options.new("max_line_length" => 24))
      output = formatter.format(ast)

      expect(output).to include("%token FIRST SECOND\n  THIRD FOURTH FIFTH")
    end

    it "formats token declarations" do
      source = <<~GRAMMAR
        %token NUMBER IDENTIFIER
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("%token")
      expect(output).to include("NUMBER")
    end

    it "aligns token declarations with type tags" do
      source = <<~GRAMMAR
        %token <node> NUMBER
        %token <id> IDENTIFIER
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("<node>")
      expect(output).to include("<id>")
    end

    it "formats precedence declarations" do
      source = <<~GRAMMAR
        %left PLUS MINUS
        %right ASSIGN
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("%left")
      expect(output).to include("%right")
    end

    it "preserves literal spelling in declarations and rules" do
      source = <<~GRAMMAR
        %token '+'
        %left "++"
        %%
        expr
            : expr '+' expr
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("%token '+'")
      expect(output).to include('"++"')
      expect(output).to include("expr '+' expr")
    end

    it "formats union declarations" do
      source = <<~GRAMMAR
        %union { int number; }
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("%union { int number; }")
    end

    it "formats inline rule declarations with bodies" do
      source = <<~GRAMMAR
        %inline opt(X): | X ;
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("%inline opt(X): | X ;")
    end

    it "formats parameterized rule declarations without empty parameter lists" do
      source = <<~GRAMMAR
        %rule opt: %empty | ITEM ;
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("%rule opt: %empty | ITEM ;")
      expect(output).not_to include("opt()")
    end

    it "formats parameterized rule declarations with empty leading alternatives" do
      source = <<~GRAMMAR
        %rule opt: | ITEM ;
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("%rule opt: | ITEM ;")
      expect(output).not_to include("%rule opt:  | ITEM ;")
    end

    it "keeps unknown declarations" do
      source = <<~GRAMMAR
        %define api.value.type {variant}
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("%define api.value.type {variant}")
    end

    it "preserves declaration order around unknown directives" do
      source = <<~GRAMMAR
        %token NUMBER
        %code requires { typedef int value_t; }
        %token IDENTIFIER
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output.index("%token NUMBER")).to be < output.index("%code requires")
      expect(output.index("%code requires")).to be < output.index("%token IDENTIFIER")
    end

    it "keeps unknown directive action blocks" do
      source = <<~GRAMMAR
        %code {
          puts "}"
        }
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("%code {\n  puts \"}\"\n}")
    end

    it "formats explicit empty alternatives" do
      source = <<~GRAMMAR
        %%
        opt
            : %empty
            | ITEM
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include(": %empty")
      expect(output).to include("| ITEM")
    end

    it "preserves empty comment markers" do
      source = <<~GRAMMAR
        %%
        opt
            : /* empty */
            | ITEM
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include(": /* empty */")
      expect(output).to include("| ITEM")
    end

    it "formats simple rules" do
      source = <<~GRAMMAR
        %%
        expr
            : NUMBER
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("expr")
      expect(output).to include(": NUMBER")
    end

    it "formats rules with multiple alternatives" do
      source = <<~GRAMMAR
        %%
        expr
            : NUMBER
            | IDENTIFIER
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include(": NUMBER")
      expect(output).to include("| IDENTIFIER")
    end

    it "preserves actions in rules" do
      source = <<~GRAMMAR
        %%
        expr
            : NUMBER { $$ = $1; }
            ;
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("{ $$ = $1; }")
    end

    it "formats complete grammar" do
      source = <<~GRAMMAR
        %token NUMBER
        %left PLUS

        %%

        expr
            : expr PLUS expr
            | NUMBER
            ;

        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("%token")
      expect(output).to include("NUMBER")
      expect(output).to include("%left")
      expect(output).to include("PLUS")
      expect(output).to include("%%")
      expect(output).to include("expr")
    end

    it "includes prologue if present" do
      source = <<~GRAMMAR
        %{
        #include <stdio.h>
        %}
        %%
        %%
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("%{")
      expect(output).to include("stdio.h")
      expect(output).to include("%}")
    end

    it "includes epilogue if present" do
      source = <<~GRAMMAR
        %%
        %%
        int main() { return 0; }
      GRAMMAR

      ast = parse_grammar(source)
      output = formatter.format(ast)

      expect(output).to include("main")
      expect(output).to include("int main() { return 0; }")
    end
  end
end
