# frozen_string_literal: true

require "spec_helper"

RSpec.describe Collie do
  it "has a version number" do
    expect(Collie::VERSION).not_to be_nil
  end
end
