require "rails_helper"

RSpec.describe Guidelines::Event, type: :model do
  subject(:event) do
    described_class.new(
      external_id: "evt_1",
      title: "Ruby meetup",
      starts_at: Time.zone.now + 1.day
    )
  end

  it "is valid with required fields" do
    expect(event).to be_valid
  end

  it "requires external_id, title, and starts_at" do
    event.external_id = nil
    event.title = nil
    event.starts_at = nil

    expect(event).not_to be_valid
    expect(event.errors[:external_id]).to include("can't be blank")
    expect(event.errors[:title]).to include("can't be blank")
    expect(event.errors[:starts_at]).to include("can't be blank")
  end

  it "requires external_id to be unique" do
    described_class.create!(
      external_id: "evt_1",
      title: "Existing event",
      starts_at: Time.zone.now + 2.days
    )

    expect(event).not_to be_valid
    expect(event.errors[:external_id]).to include("has already been taken")
  end

  it "exposes a type id for ObjectRepository" do
    event.external_id = "abc123"
    expect(event.tid).to eq("Event$abc123")
  end
end
