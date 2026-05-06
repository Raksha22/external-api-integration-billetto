# frozen_string_literal: true

module Guidelines
  class Service
    include Command::Handler

    handles SyncPublicEvents, :sync_public_events

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

    private

    def build_importer
      return @importer_class.new if @importer_class

      client = (@client_class || Billetto::Client).new
      PublicEventsImporter.new(client: client)
    end
  end
end
