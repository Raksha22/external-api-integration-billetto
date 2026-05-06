# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObjectRepository do
  describe ".find" do
    it "resolves Event$external_id to Guidelines::Event" do
      evt = Guidelines::Event.create!(
        external_id: "repo_evt_x",
        title: "Repo Event",
        starts_at: 1.day.from_now
      )

      expect(described_class.find("Event$repo_evt_x")).to eq(evt)
    end

    it "raises UnknownObjectError when the identifier has no id segment" do
      expect { described_class.find("Event") }.to raise_error(
        ObjectRepository::UnknownObjectError,
        "Event"
      )
    end

    it "raises UnknownObjectError for unsupported type prefixes" do
      expect { described_class.find("Unknown$foo") }.to raise_error(
        ObjectRepository::UnknownObjectError,
        "Unknown$foo"
      )
    end

    it "raises when Event row is missing" do
      expect { described_class.find("Event$no_such_external") }.to raise_error(
        ActiveRecord::RecordNotFound
      )
    end
  end
end
