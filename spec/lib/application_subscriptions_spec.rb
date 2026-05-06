# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationSubscriptions do
  describe ".handlers" do
    it "merges Guidelines.subscriptions into top_level_subscriptions" do
      guidelines = Guidelines.subscriptions

      expect(described_class.handlers.keys).to include(*guidelines.keys)

      guidelines.each_key do |key|
        spec = described_class.handlers.fetch(key)
        expect(spec[:to]).to eq(guidelines.fetch(key)[:to])
        expect(spec[:handler]).to be_a(Proc)
        expect(spec[:handler].call).to be_a(Guidelines::ProjectEventVoteCounts)
      end
    end

    it "preserves top-level keys when Guidelines adds context-specific keys" do
      demo_handler = Object.new
      demo_handler.define_singleton_method(:call) { |_event| nil }

      allow(described_class).to receive(:top_level_subscriptions).and_return(
        {
          demo_integrator_probe: {
            handler: -> { demo_handler },
            to: [Guidelines::EventUpvoted]
          }
        }
      )

      merged = described_class.handlers

      expect(merged).to include(:demo_integrator_probe, :guidelines_vote_count_projection)
      expect(merged[:demo_integrator_probe][:handler].call).to be(demo_handler)
      expect(merged[:guidelines_vote_count_projection][:to]).to eq(
        [Guidelines::EventUpvoted, Guidelines::EventDownvoted]
      )
    end
  end

  describe ".subscribe_rails_event_store!" do
    let(:store) { instance_double(RailsEventStore::Client, subscribe: nil) }

    it "subscribes each handler from handlers to its fact types" do
      projector = Guidelines::ProjectEventVoteCounts.new

      allow(Guidelines::ProjectEventVoteCounts).to receive(:new).and_return(projector)

      described_class.subscribe_rails_event_store!(store)

      expect(store).to have_received(:subscribe).with(
        projector,
        to: [Guidelines::EventUpvoted, Guidelines::EventDownvoted]
      )
    end

    it "raises when a subscription entry omits :handler" do
      allow(described_class).to receive(:handlers).and_return(
        { broken: { to: [Guidelines::EventUpvoted] } }
      )

      expect do
        described_class.subscribe_rails_event_store!(store)
      end.to raise_error(KeyError, /handler/)
    end

    it "raises when a subscription entry omits :to" do
      allow(described_class).to receive(:handlers).and_return(
        { broken: { handler: -> { Object.new } } }
      )

      expect do
        described_class.subscribe_rails_event_store!(store)
      end.to raise_error(KeyError, /to/)
    end

    it "subscribes multiple handlers when top_level and Guidelines both register" do
      extra = Object.new
      extra.define_singleton_method(:call) { |_e| nil }

      allow(described_class).to receive(:top_level_subscriptions).and_return(
        {
          extra_projection: {
            handler: -> { extra },
            to: [Guidelines::PublicEventsSynced]
          }
        }
      )

      described_class.subscribe_rails_event_store!(store)

      expect(store).to have_received(:subscribe).twice
      expect(store).to have_received(:subscribe).with(
        kind_of(Guidelines::ProjectEventVoteCounts),
        to: [Guidelines::EventUpvoted, Guidelines::EventDownvoted]
      )
      expect(store).to have_received(:subscribe).with(
        extra,
        to: [Guidelines::PublicEventsSynced]
      )
    end
  end
end
