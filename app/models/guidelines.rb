# frozen_string_literal: true

# Bounded context root (Developer's Guide). Constants live under app/models/guidelines/.
module Guidelines
  # Recompute vote counters from historic facts (migrations, ops).
  def self.rebuild_vote_counts!
    ProjectEventVoteCounts.rebuild!
  end

  # Developer's Guide: merged into ApplicationSubscriptions.handlers → RES subscribe in initializer.
  def self.subscriptions
    {
      guidelines_vote_count_projection: {
        handler: -> { ProjectEventVoteCounts.new },
        to: [EventUpvoted, EventDownvoted]
      }
    }
  end
end
