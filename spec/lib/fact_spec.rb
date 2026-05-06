# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fact do
  describe "#stream_names" do
    it "returns an empty list by default (subclasses override)" do
      expect(described_class.new(data: {}).stream_names).to eq([])
    end
  end
end
