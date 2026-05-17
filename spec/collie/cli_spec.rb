# frozen_string_literal: true

require "spec_helper"

RSpec.describe Collie::CLI do
  describe "#format_source" do
    it "rejects formatted output that changes grammar structure" do
      source = <<~GRAMMAR
        %token NUMBER
        %%
        expr
            : NUMBER
            ;
        %%
      GRAMMAR
      formatter = Class.new do
        def format(_ast)
          "%%\n%%"
        end
      end.new
      result = nil

      expect do
        result = described_class.new.send(:format_source, source, formatter, filename: "test.y")
      end.to output(/Formatted output changed grammar structure/).to_stdout
      expect(result).to be_nil
    end
  end
end
