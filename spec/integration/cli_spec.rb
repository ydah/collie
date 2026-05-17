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

    it "exits with failure for missing files" do
      output = `bundle exec exe/collie lint /tmp/collie-missing-file.y 2>&1`

      expect(output).to include("File not found")
      expect($CHILD_STATUS.exitstatus).to eq(1)
    end

    it "supports comma-separated --only rule names" do
      Tempfile.create(["test", ".y"]) do |f|
        f.write(<<~GRAMMAR)
          %token NUMBER NUMBER
          %%
          %%
        GRAMMAR
        f.flush

        output = `bundle exec exe/collie lint --only=DuplicateToken,TokenNaming #{f.path} 2>&1`

        expect(output).to include("DuplicateToken")
        expect($CHILD_STATUS.exitstatus).to eq(1)
      end
    end

    it "uses fail-level to decide the exit status" do
      Tempfile.create(["test", ".y"]) do |f|
        f.write(<<~GRAMMAR)
          %token lowercase
          %%
          %%
        GRAMMAR
        f.flush

        output = `bundle exec exe/collie lint --only=TokenNaming --fail-level convention #{f.path} 2>&1`

        expect(output).to include("TokenNaming")
        expect($CHILD_STATUS.exitstatus).to eq(1)
      end
    end

    it "supports SARIF output" do
      Tempfile.create(["test", ".y"]) do |f|
        f.write(<<~GRAMMAR)
          %token NUMBER NUMBER
          %%
          %%
        GRAMMAR
        f.flush

        output = `bundle exec exe/collie lint --format sarif #{f.path} 2>&1`
        data = JSON.parse(output)

        expect(data["version"]).to eq("2.1.0")
        expect(data["runs"].first["results"].first["ruleId"]).to eq("DuplicateToken")
        expect($CHILD_STATUS.exitstatus).to eq(1)
      end
    end

    it "reports parse errors through reporters" do
      Tempfile.create(["test", ".y"]) do |f|
        f.write("%token NUMBER\n")
        f.flush

        output = `bundle exec exe/collie lint --format github #{f.path} 2>&1`

        expect(output).to include("::error")
        expect(output).to include("Expected SECTION_SEPARATOR")
        expect($CHILD_STATUS.exitstatus).to eq(1)
      end
    end

    it "lints source from stdin" do
      command = "printf '%s' '%token NUMBER NUMBER\n%%\n%%\n' | " \
                "bundle exec exe/collie lint --stdin --stdin-filename stdin.y"
      output = `#{command} 2>&1`

      expect(output).to include("stdin.y")
      expect(output).to include("DuplicateToken")
      expect($CHILD_STATUS.exitstatus).to eq(1)
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

    it "exits with failure when --check finds formatting changes" do
      Tempfile.create(["test", ".y"]) do |f|
        f.write("%token NUMBER\n%%\n%%\n")
        f.flush

        output = `bundle exec exe/collie fmt --check #{f.path} 2>&1`

        expect(output).to include("needs formatting")
        expect($CHILD_STATUS.exitstatus).to eq(1)
      end
    end

    it "shows --diff without rewriting files" do
      source = "%token NUMBER\n%%\n%%\n"

      Tempfile.create(["test", ".y"]) do |f|
        f.write(source)
        f.flush

        output = `bundle exec exe/collie fmt --diff #{f.path} 2>&1`

        expect(output).to include("needs formatting")
        expect(output).to include("@@")
        expect(File.read(f.path)).to eq(source)
        expect($CHILD_STATUS.exitstatus).to eq(1)
      end
    end

    it "exits with failure for missing files" do
      output = `bundle exec exe/collie fmt /tmp/collie-missing-file.y 2>&1`

      expect(output).to include("File not found")
      expect($CHILD_STATUS.exitstatus).to eq(1)
    end

    it "formats source from stdin" do
      command = "printf '%s' '%%\nexpr: NUMBER ;\n%%\n' | bundle exec exe/collie fmt --stdin"
      output = `#{command} 2>&1`

      expect(output).to include("expr")
      expect(output).to include(": NUMBER")
      expect($CHILD_STATUS.exitstatus).to eq(0)
    end
  end

  describe "rules command" do
    it "lists all rules" do
      output = `bundle exec exe/collie rules 2>&1`
      expect(output).to include("DuplicateToken")
      expect(output).to include("UndefinedSymbol")
      expect(output).to include("TokenNaming")
    end

    it "includes config-reflected metadata as JSON" do
      Tempfile.create(["config", ".yml"]) do |f|
        f.write(<<~YAML)
          rules:
            TokenNaming:
              enabled: false
              severity: error
        YAML
        f.flush

        output = `bundle exec exe/collie rules --format json --config #{f.path} 2>&1`
        data = JSON.parse(output)
        token_naming = data.find { |rule| rule["name"] == "TokenNaming" }

        expect(token_naming["enabled"]).to be false
        expect(token_naming["severity"]).to eq("error")
      end
    end
  end

  describe "explain command" do
    it "explains a rule" do
      output = `bundle exec exe/collie explain DuplicateToken 2>&1`

      expect(output).to include("DuplicateToken")
      expect(output).to include("Severity:")
      expect($CHILD_STATUS.exitstatus).to eq(0)
    end

    it "exits with failure for unknown rules" do
      output = `bundle exec exe/collie explain MissingRule 2>&1`

      expect(output).to include("Unknown rule")
      expect($CHILD_STATUS.exitstatus).to eq(1)
    end
  end

  describe "version command" do
    it "shows version" do
      output = `bundle exec exe/collie version 2>&1`
      expect(output).to include(Collie::VERSION)
    end
  end
end
