# frozen_string_literal: true

require "rails_helper"

RSpec.describe Guidelines::ProjectEventVoteCounts do
  let(:store) { Rails.configuration.event_store }

  describe "#call" do
    let(:projector) { described_class.new }

    let!(:event) do
      Guidelines::Event.create!(
        external_id: "direct_call_evt",
        title: "Direct call",
        starts_at: 1.day.from_now,
        upvotes_count: 2,
        downvotes_count: 3
      )
    end

    it "no-ops for fact classes that are not vote facts" do
      fact = Guidelines::PublicEventsSynced.strict(
        data: { imported_count: 1, updated_count: 0, skipped_count: 0 }
      )

      up_before = event.reload.upvotes_count
      down_before = event.reload.downvotes_count

      projector.call(fact)
      event.reload

      expect(event.upvotes_count).to eq(up_before)
      expect(event.downvotes_count).to eq(down_before)
    end

    it "raises KeyError when event_external_id is missing from data" do
      broken = Guidelines::EventUpvoted.new(data: { clerk_user_id: "only_user" })

      expect { projector.call(broken) }.to raise_error(KeyError, /event_external_id/)
    end

    it "increments upvotes_count when invoked directly with EventUpvoted" do
      fact = Guidelines::EventUpvoted.strict(
        data: { event_external_id: event.external_id, clerk_user_id: "u1" }
      )

      projector.call(fact)

      expect(event.reload.upvotes_count).to eq(3)
      expect(event.reload.downvotes_count).to eq(3)
    end

    it "increments downvotes_count when invoked directly with EventDownvoted" do
      fact = Guidelines::EventDownvoted.strict(
        data: { event_external_id: event.external_id, clerk_user_id: "u2" }
      )

      projector.call(fact)

      expect(event.reload.upvotes_count).to eq(2)
      expect(event.reload.downvotes_count).to eq(4)
    end

    it "applies multiple increments when call runs repeatedly" do
      fact = Guidelines::EventUpvoted.strict(
        data: { event_external_id: event.external_id, clerk_user_id: "u1" }
      )

      4.times { projector.call(fact) }

      expect(event.reload.upvotes_count).to eq(6)
    end

    it "targets the row matching event_external_id only" do
      other = Guidelines::Event.create!(
        external_id: "other_evt",
        title: "Other",
        starts_at: 2.days.from_now,
        upvotes_count: 10,
        downvotes_count: 10
      )

      fact = Guidelines::EventUpvoted.strict(
        data: { event_external_id: event.external_id, clerk_user_id: "u1" }
      )

      projector.call(fact)

      expect(event.reload.upvotes_count).to eq(3)
      expect(other.reload.upvotes_count).to eq(10)
    end
  end

  describe "#call (via RES subscription)" do
    let!(:event) do
      Guidelines::Event.create!(
        external_id: "proj_vote_evt",
        title: "Projection Event",
        starts_at: 1.day.from_now
      )
    end

    it "increments upvotes_count when EventUpvoted is published" do
      fact = Guidelines::EventUpvoted.strict(
        data: {
          event_external_id: event.external_id,
          clerk_user_id: "u1"
        }
      )
      store.publish(fact, stream_name: fact.stream_names.first)

      expect(event.reload.upvotes_count).to eq(1)
    end

    it "increments downvotes_count when EventDownvoted is published" do
      fact = Guidelines::EventDownvoted.strict(
        data: {
          event_external_id: event.external_id,
          clerk_user_id: "u2"
        }
      )
      store.publish(fact, stream_name: fact.stream_names.first)

      expect(event.reload.downvotes_count).to eq(1)
    end

    it "does not raise when no matching read-model row exists" do
      fact = Guidelines::EventUpvoted.strict(
        data: {
          event_external_id: "ghost_external_id",
          clerk_user_id: "u1"
        }
      )

      expect do
        store.publish(fact, stream_name: fact.stream_names.first)
      end.not_to raise_error
    end

    it "chains subscriber increments across multiple publishes for the same event" do
      body = ->(uid) do
        Guidelines::EventUpvoted.strict(
          data: { event_external_id: event.external_id, clerk_user_id: uid }
        )
      end

      store.publish(body.call("a"), stream_name: body.call("a").stream_names.first)
      store.publish(body.call("b"), stream_name: body.call("b").stream_names.first)

      expect(event.reload.upvotes_count).to eq(2)
    end
  end

  describe ".rebuild!" do
    let!(:event_a) do
      Guidelines::Event.create!(
        external_id: "rebuild_a",
        title: "A",
        starts_at: 1.day.from_now,
        upvotes_count: 99,
        downvotes_count: 99
      )
    end

    let!(:event_b) do
      Guidelines::Event.create!(
        external_id: "rebuild_b",
        title: "B",
        starts_at: 2.days.from_now,
        upvotes_count: 1,
        downvotes_count: 0
      )
    end

    before do
      %w[u1 u2 u3].each do |uid|
        f = Guidelines::EventUpvoted.strict(
          data: { event_external_id: "rebuild_a", clerk_user_id: uid }
        )
        store.publish(f, stream_name: f.stream_names.first)
      end
      fd = Guidelines::EventDownvoted.strict(
        data: { event_external_id: "rebuild_b", clerk_user_id: "u9" }
      )
      store.publish(fd, stream_name: fd.stream_names.first)
      fd2 = Guidelines::EventDownvoted.strict(
        data: { event_external_id: "rebuild_b", clerk_user_id: "u8" }
      )
      store.publish(fd2, stream_name: fd2.stream_names.first)
    end

    it "resets and recomputes counts from the event store" do
      described_class.rebuild!(store)

      expect(event_a.reload.upvotes_count).to eq(3)
      expect(event_a.reload.downvotes_count).to eq(0)
      expect(event_b.reload.upvotes_count).to eq(0)
      expect(event_b.reload.downvotes_count).to eq(2)
    end
  end

  describe ".rebuild! edge cases" do
    let(:store) { Rails.configuration.event_store }

    it "zeros all events when the store has no vote facts" do
      Guidelines::Event.create!(
        external_id: "silent_evt",
        title: "No votes",
        starts_at: 1.day.from_now,
        upvotes_count: 7,
        downvotes_count: 11
      )

      described_class.rebuild!(store)

      row = Guidelines::Event.find_by!(external_id: "silent_evt")
      expect(row.upvotes_count).to eq(0)
      expect(row.downvotes_count).to eq(0)
    end

    it "does not raise when vote facts reference an external_id not present in events" do
      Guidelines::Event.create!(
        external_id: "only_real",
        title: "Real",
        starts_at: 1.day.from_now,
        upvotes_count: 0,
        downvotes_count: 0
      )

      orphan = Guidelines::EventUpvoted.strict(
        data: { event_external_id: "missing_from_sql", clerk_user_id: "u1" }
      )
      store.publish(orphan, stream_name: orphan.stream_names.first)

      expect { described_class.rebuild!(store) }.not_to raise_error

      expect(Guidelines::Event.find_by!(external_id: "only_real").upvotes_count).to eq(0)
    end

    it "ignores non-vote facts when recomputing tallies" do
      evt = Guidelines::Event.create!(
        external_id: "sync_only_evt",
        title: "Sync",
        starts_at: 1.day.from_now,
        upvotes_count: 5,
        downvotes_count: 5
      )

      sync_fact = Guidelines::PublicEventsSynced.strict(
        data: { imported_count: 1, updated_count: 0, skipped_count: 0 }
      )
      store.publish(sync_fact, stream_name: sync_fact.stream_names.first)

      described_class.rebuild!(store)

      expect(evt.reload.upvotes_count).to eq(0)
      expect(evt.reload.downvotes_count).to eq(0)
    end

    it "is idempotent when run twice against the same store contents" do
      evt = Guidelines::Event.create!(
        external_id: "idempotent_evt",
        title: "Idempotent",
        starts_at: 1.day.from_now
      )

      fact = Guidelines::EventDownvoted.strict(
        data: { event_external_id: evt.external_id, clerk_user_id: "u1" }
      )
      store.publish(fact, stream_name: fact.stream_names.first)

      2.times { described_class.rebuild!(store) }

      expect(evt.reload.downvotes_count).to eq(1)
      expect(evt.reload.upvotes_count).to eq(0)
    end
  end
end
