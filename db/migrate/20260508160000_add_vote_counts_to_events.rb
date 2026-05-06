# frozen_string_literal: true

class AddVoteCountsToEvents < ActiveRecord::Migration[7.1]
  def up
    add_column :events, :upvotes_count, :integer, null: false, default: 0
    add_column :events, :downvotes_count, :integer, null: false, default: 0

    say_with_time "backfill vote counts from Rails Event Store" do
      Guidelines.rebuild_vote_counts!
    end
  end

  def down
    remove_column :events, :downvotes_count
    remove_column :events, :upvotes_count
  end
end
