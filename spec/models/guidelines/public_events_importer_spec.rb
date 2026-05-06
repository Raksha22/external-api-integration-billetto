require "rails_helper"

RSpec.describe Guidelines::PublicEventsImporter do
  describe "#call" do
    let(:client) { instance_double(Billetto::Client) }
    let(:service) { described_class.new(client: client) }

    it "imports new events and updates existing events" do
      existing = Guidelines::Event.create!(
        external_id: "123",
        title: "Old title",
        starts_at: Time.zone.parse("2026-01-01T10:00:00Z")
      )

      allow(client).to receive(:list_public_events).and_return(
        [
          {
            "id" => existing.external_id,
            "title" => "Updated title",
            "starts_at" => "2026-01-02T10:00:00Z",
            "description" => "Updated"
          },
          {
            "id" => "999",
            "title" => "Brand new",
            "starts_at" => "2026-01-03T10:00:00Z",
            "description" => "New event"
          }
        ]
      )

      result = service.call(limit: 50)

      expect(result.imported_count).to eq(1)
      expect(result.updated_count).to eq(1)
      expect(result.skipped_count).to eq(0)

      expect(existing.reload.title).to eq("Updated title")
      expect(Guidelines::Event.find_by(external_id: "999")).to be_present
    end

    it "accepts Billetto-style start fields (e.g. startDate or nested event)" do
      allow(client).to receive(:list_public_events).and_return(
        [
          { "id" => "a", "title" => "Alpha", "startDate" => "2026-06-01T18:00:00Z" },
          { "id" => "b", "title" => "Beta", "event" => { "starts_at" => "2026-06-02T18:00:00Z" } }
        ]
      )

      result = service.call(limit: 50)

      expect(result.skipped_count).to eq(0)
      expect(result.imported_count).to eq(2)
      expect(Guidelines::Event.find_by(external_id: "a").starts_at).to eq(Time.zone.parse("2026-06-01T18:00:00Z"))
    end

    it "skips invalid payload rows and records errors" do
      allow(client).to receive(:list_public_events).and_return(
        [
          { "title" => "Missing id", "starts_at" => "2026-01-03T10:00:00Z" },
          { "id" => "ok", "title" => "Valid", "starts_at" => "2026-01-04T10:00:00Z" }
        ]
      )

      result = service.call(limit: 50)

      expect(result.imported_count).to eq(1)
      expect(result.skipped_count).to eq(1)
      expect(result.errors).not_to be_empty
    end

    it "skips rows when starts_at cannot be parsed" do
      allow(client).to receive(:list_public_events).and_return(
        [
          { "id" => "bad_date", "title" => "Bad date", "starts_at" => "not-a-timestamp" },
          { "id" => "good", "title" => "Good", "starts_at" => "2026-01-05T10:00:00Z" }
        ]
      )

      result = service.call(limit: 50)

      expect(result.imported_count).to eq(1)
      expect(result.skipped_count).to eq(1)
      expect(result.errors.join).to match(/Invalid starts_at|starts_at/)
    end
  end
end
