# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventStoreInjector do
  it "is mixed into Guidelines::Event" do
    expect(Guidelines::Event.included_modules).to include(described_class)
  end

  it "exposes event_store from Rails.configuration" do
    evt = Guidelines::Event.new
    expect(evt.event_store).to eq(Rails.configuration.event_store)
  end
end
