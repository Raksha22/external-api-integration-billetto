require "rails_helper"

RSpec.describe "Events", type: :request do
  describe "GET /events" do
    it "renders the events listing page" do
      get events_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Billetto Events")
    end

    it "shows vote totals from the read model on each event card" do
      Guidelines::Event.create!(
        external_id: "votes_ui_evt",
        title: "Listed With Votes",
        starts_at: 1.day.from_now,
        upvotes_count: 4,
        downvotes_count: 1
      )

      get events_path

      expect(response.body).to include("Votes:")
      expect(response.body).to include("4 like")
      expect(response.body).to include("1 dislike")
    end
  end

  describe "POST /events/sync" do
    it "redirects with success notice when command bus sync succeeds" do
      result = Guidelines::PublicEventsImporter::Result.new(
        imported_count: 2,
        updated_count: 1,
        skipped_count: 0,
        errors: []
      )

      bus = instance_double(Command::Bus)
      allow(Rails.configuration).to receive(:command_bus).and_return(bus)
      allow(bus).to receive(:call).and_return(result)

      post sync_events_path

      expect(response).to redirect_to(events_path)
      follow_redirect!
      expect(response.body).to include("Sync complete: 2 imported, 1 updated")
    end

    it "mentions skipped rows when the importer skipped some payloads" do
      result = Guidelines::PublicEventsImporter::Result.new(
        imported_count: 0,
        updated_count: 0,
        skipped_count: 3,
        errors: ["bad row"]
      )

      bus = instance_double(Command::Bus)
      allow(Rails.configuration).to receive(:command_bus).and_return(bus)
      allow(bus).to receive(:call).and_return(result)

      post sync_events_path

      follow_redirect!
      expect(response.body).to include("3 skipped")
    end

    it "redirects with alert when sync raises Billetto::Error" do
      bus = instance_double(Command::Bus)
      allow(Rails.configuration).to receive(:command_bus).and_return(bus)
      allow(bus).to receive(:call).and_raise(Billetto::Client::RequestFailedError.new("upstream failure"))

      post sync_events_path

      expect(response).to redirect_to(events_path)
      follow_redirect!
      expect(response.body).to include("Billetto sync failed")
      expect(response.body).to include("upstream failure")
    end

    it "redirects with alert when sync limit is out of range" do
      post sync_events_path, params: { limit: 101 }

      expect(response).to redirect_to(events_path)
      follow_redirect!
      expect(response.body).to match(/100/)
    end
  end
end
