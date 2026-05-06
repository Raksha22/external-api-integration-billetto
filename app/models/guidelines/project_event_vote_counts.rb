# frozen_string_literal: true

module Guidelines
  # Read-model projection: vote totals on Guidelines::Event (Step 3).
  class ProjectEventVoteCounts
    INCREMENT_COLUMNS = {
      EventUpvoted => :upvotes_count,
      EventDownvoted => :downvotes_count
    }.freeze

    VOTE_FACT_TYPES = INCREMENT_COLUMNS.keys.freeze

    def call(event)
      column = INCREMENT_COLUMNS[event.class]
      return unless column

      external_id = event.data.fetch(:event_external_id)
      quoted = Event.connection.quote_column_name(column)
      Event.where(external_id: external_id).update_all("#{quoted} = #{quoted} + 1")
    end

    def self.rebuild!(event_store = Rails.configuration.event_store)
      Event.update_all(upvotes_count: 0, downvotes_count: 0)

      tallies = Hash.new do |h, external_id|
        h[external_id] = { upvotes_count: 0, downvotes_count: 0 }
      end

      event_store.read.of_type(VOTE_FACT_TYPES).each do |ev|
        column = INCREMENT_COLUMNS[ev.class]
        next unless column

        ext = ev.data.fetch(:event_external_id)
        tallies[ext][column] += 1
      end

      tallies.each do |external_id, counts|
        Event.where(external_id: external_id).update_all(counts)
      end
    end
  end
end
