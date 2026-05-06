# frozen_string_literal: true

require "rails_helper"

RSpec.describe ClerkHelper, type: :helper do
  describe "#clerk_frontend_api_origin" do
    around do |example|
      previous = ENV["CLERK_PUBLISHABLE_KEY"]
      example.run
    ensure
      ENV["CLERK_PUBLISHABLE_KEY"] = previous
    end

    it "returns nil when decode_publishable_key raises ArgumentError" do
      ENV["CLERK_PUBLISHABLE_KEY"] = "pk_invalid"

      allow(Clerk::Utils).to receive(:decode_publishable_key).and_raise(ArgumentError)

      expect(helper.clerk_frontend_api_origin).to be_nil
    end
  end
end
