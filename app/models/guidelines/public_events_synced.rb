# frozen_string_literal: true

module Guidelines
  class PublicEventsSynced < Fact
    SCHEMA = {
      imported_count: Integer,
      updated_count: Integer,
      skipped_count: Integer
    }.freeze

    def stream_names
      ["Guidelines$public_events_sync"]
    end
  end
end
