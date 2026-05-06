# frozen_string_literal: true

require "rails_helper"

RSpec.describe Guidelines::RecordEventVote do
  subject(:cmd) do
    described_class.new(
      event_external_id: "evt1",
      clerk_user_id: "user_1",
      direction: "up"
    )
  end

  it "is valid for up and down" do
    expect(cmd).to be_valid

    cmd.direction = "down"
    expect(cmd).to be_valid
  end

  it "requires event_external_id, clerk_user_id, and direction" do
    cmd.event_external_id = ""
    cmd.clerk_user_id = ""
    cmd.direction = ""

    expect(cmd).not_to be_valid
    expect(cmd.errors.attribute_names).to include(:event_external_id, :clerk_user_id, :direction)
  end

  it "rejects directions other than up or down" do
    cmd.direction = "sideways"
    expect(cmd).not_to be_valid
    expect(cmd.errors[:direction]).to be_present
  end
end
