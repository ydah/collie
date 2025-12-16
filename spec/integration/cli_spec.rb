# frozen_string_literal: true

require "English"
require "spec_helper"
require "tempfile"

RSpec.describe "CLI integration" do
  let(:simple_grammar) do
    <<~GRAMMAR
      %token NUMBER IDENTIFIER PLUS MINUS
      %left PLUS MINUS

      %%

      expr
          : expr PLUS expr
          | expr MINUS expr
          | NUMBER
          | IDENTIFIER
          ;

      %%
    GRAMMAR
  end

  let(:valid_grammar_without_warnings) do
    <<~GRAMMAR
      %token NUMBER IDENTIFIER

      %%

      expr
          : NUMBER
          | IDENTIFIER
          ;

      %%
    GRAMMAR
  end

  describe "lint command" do
    it "lints a valid file" do
      Tempfile.create(["test", ".y"]) do |f|
        f.write(valid_grammar_without_warnings)
        f.flush

        output = `bundle exec exe/collie lint #{f.path} 2>&1`
        expect(output).to include("No offenses detected").or include("✓")
        expect($CHILD_STATUS.exitstatus).to eq(0), "Expected exit 0, got #{$CHILD_STATUS.exitstatus}. Output: #{output}"
      end
    end

    it "autocorrects offenses with -a flag" do
      # NOTE: Explicit trailing spaces added to lines
      grammar_with_trailing_whitespace = "%token NUMBER  \n\n%%\n\nexpr: NUMBER ;  \n\n%%\n"

      Tempfile.create(["test", ".y"]) do |f|
        f.write(grammar_with_trailing_whitespace)
        f.flush

        # Verify trailing whitespace exists before autocorrect
        original_content = File.read(f.path)
        expect(original_content).to match(/[ \t]+\n/)

        output = `bundle exec exe/collie lint -a #{f.path} 2>&1`
        expect(output).to include("Auto-corrected")

        corrected_content = File.read(f.path)
        expect(corrected_content).not_to match(/[ \t]+$/)
        expect(corrected_content).not_to match(/[ \t]+\n/)
      end
    end
  end

  describe "fmt command" do
    it "formats a file" do
      Tempfile.create(["test", ".y"]) do |f|
        f.write(simple_grammar)
        f.flush

        `bundle exec exe/collie fmt --check #{f.path} 2>&1`
        # May or may not need formatting, just ensure it runs
        expect($CHILD_STATUS.exitstatus).to be_between(0, 1)
      end
    end
  end

  describe "rules command" do
    it "lists all rules" do
      output = `bundle exec exe/collie rules 2>&1`
      expect(output).to include("DuplicateToken")
      expect(output).to include("UndefinedSymbol")
      expect(output).to include("TokenNaming")
    end
  end

  describe "version command" do
    it "shows version" do
      output = `bundle exec exe/collie version 2>&1`
      expect(output).to include(Collie::VERSION)
    end
  end
end
