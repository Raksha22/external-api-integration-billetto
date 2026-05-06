# frozen_string_literal: true

require "rails_helper"

RSpec.describe Guidelines::Service do
  let(:service) { described_class.new }

  describe "#sync_public_events" do
    let(:importer_result) do
      Guidelines::PublicEventsImporter::Result.new(
        imported_count: 1,
        updated_count: 2,
        skipped_count: 3,
        errors: ["skipped row"]
      )
    end

    let(:importer_class) do
      result = importer_result
      Class.new do
        define_method(:call) { |limit:| result }
      end
    end

    let(:service_with_stub_importer) { described_class.new(importer: importer_class) }

    it "returns the importer result" do
      cmd = Guidelines::SyncPublicEvents.new(limit: 50)
      expect(service_with_stub_importer.sync_public_events(cmd)).to eq(importer_result)
    end

    it "publishes PublicEventsSynced with importer counts to Rails Event Store" do
      cmd = Guidelines::SyncPublicEvents.new(limit: 50)

      expect do
        service_with_stub_importer.sync_public_events(cmd)
      end.to(change do
        ActiveRecord::Base.connection.select_value(
          "SELECT COUNT(*) FROM event_store_events WHERE event_type LIKE '%PublicEventsSynced%'"
        ).to_i
      end.by(1))

      row = ActiveRecord::Base.connection.select_one(
        "SELECT event_type, data FROM event_store_events WHERE event_type LIKE '%PublicEventsSynced%' ORDER BY id DESC LIMIT 1"
      )

      expect(row["event_type"]).to include("PublicEventsSynced")

      payload = decode_event_store_data(row["data"])
      data = Psych.safe_load(payload, permitted_classes: [Symbol])
      expect(data[:imported_count]).to eq(1)
      expect(data[:updated_count]).to eq(2)
      expect(data[:skipped_count]).to eq(3)
    end
  end

  describe "#record_event_vote" do
    let!(:event) do
      Guidelines::Event.create!(
        external_id: "service_vote_evt",
        title: "Service Vote Event",
        starts_at: 1.day.from_now
      )
    end

    it "publishes EventUpvoted and links event and clerk user streams" do
      cmd = Guidelines::RecordEventVote.new(
        event_external_id: event.external_id,
        clerk_user_id: "user_streams_test",
        direction: "up"
      )

      expect do
        service.record_event_vote(cmd)
      end.to(change do
        ActiveRecord::Base.connection.select_value(
          "SELECT COUNT(*) FROM event_store_events WHERE event_type LIKE '%EventUpvoted%'"
        ).to_i
      end.by(1))

      event_id = ActiveRecord::Base.connection.select_value(
        "SELECT event_id FROM event_store_events WHERE event_type LIKE '%EventUpvoted%' ORDER BY id DESC LIMIT 1"
      )

      streams = ActiveRecord::Base.connection.select_values(
        ActiveRecord::Base.sanitize_sql_array([
          "SELECT stream FROM event_store_events_in_streams WHERE event_id = ? ORDER BY stream",
          event_id
        ])
      )

      expect(streams).to eq(
        [
          "Guidelines$clerk_user$user_streams_test",
          "Guidelines$event$service_vote_evt"
        ]
      )
    end

    it "raises when event external id is unknown" do
      cmd = Guidelines::RecordEventVote.new(
        event_external_id: "no_such_event",
        clerk_user_id: "u1",
        direction: "down"
      )

      expect { service.record_event_vote(cmd) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
