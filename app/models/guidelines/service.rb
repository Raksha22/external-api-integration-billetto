# frozen_string_literal: true

module Guidelines
  class Service
    include Command::Handler

    handles SyncPublicEvents, :sync_public_events
    handles RecordEventVote, :record_event_vote

    def initialize(importer: nil, client: nil)
      @importer_class = importer
      @client_class = client
    end

    def sync_public_events(cmd)
      importer = build_importer
      result = ActiveRecord::Base.transaction { importer.call(limit: cmd.limit) }

      fact = PublicEventsSynced.strict(
        data: {
          imported_count: result.imported_count,
          updated_count: result.updated_count,
          skipped_count: result.skipped_count
        }
      )
      event_store.publish(fact, stream_name: fact.stream_names.first)
      result
    end

    def record_event_vote(cmd)
      Guidelines::Event.find_by!(external_id: cmd.event_external_id)

      fact =
        if cmd.up?
          EventUpvoted.strict(
            data: {
              event_external_id: cmd.event_external_id,
              clerk_user_id: cmd.clerk_user_id
            }
          )
        else
          EventDownvoted.strict(
            data: {
              event_external_id: cmd.event_external_id,
              clerk_user_id: cmd.clerk_user_id
            }
          )
        end

      primary = fact.stream_names.first
      event_store.publish(fact, stream_name: primary)
      secondary = fact.stream_names[1]
      if secondary.present?
        event_store.link(fact.event_id, stream_name: secondary, expected_version: :any)
      end
      nil
    end

    private

    def build_importer
      return @importer_class.new if @importer_class

      client = (@client_class || Billetto::Client).new
      PublicEventsImporter.new(client: client)
    end
  end
end
