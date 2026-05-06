require "rails_helper"

RSpec.describe "Events", type: :request do
  describe "GET /events" do
    it "renders the events listing page" do
      get events_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Billetto Events")
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
  end
end
