# frozen_string_literal: true

module Guidelines
  class EventDownvoted < Fact
    SCHEMA = {
      event_external_id: String,
      clerk_user_id: String
    }.freeze

    def stream_names
      ext = data.fetch(:event_external_id)
      uid = data.fetch(:clerk_user_id)
      ["Guidelines$event$#{ext}", "Guidelines$clerk_user$#{uid}"]
    end
  end
end
