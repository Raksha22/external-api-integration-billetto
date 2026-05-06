# frozen_string_literal: true

require "rails_helper"

RSpec.describe Guidelines do
  describe ".subscriptions" do
    subject(:subscriptions) { described_class.subscriptions }

    it "registers vote count projection with vote facts only" do
      spec = subscriptions[:guidelines_vote_count_projection]

      expect(spec).to be_a(Hash)
      expect(spec[:to]).to eq([Guidelines::EventUpvoted, Guidelines::EventDownvoted])
      expect(spec[:handler]).to be_a(Proc)
      expect(spec[:handler].call).to be_a(Guidelines::ProjectEventVoteCounts)
    end

    it "uses a fresh projector instance per handler lambda invocation" do
      spec = subscriptions[:guidelines_vote_count_projection]
      first = spec[:handler].call
      second = spec[:handler].call

      expect(first).to be_a(Guidelines::ProjectEventVoteCounts)
      expect(second).to be_a(Guidelines::ProjectEventVoteCounts)
      expect(first).not_to be(second)
    end

    it "keeps subscription keys stable for ApplicationSubscriptions.merge" do
      expect(subscriptions.keys).to eq([:guidelines_vote_count_projection])
    end
  end

  describe ".rebuild_vote_counts!" do
    it "delegates to ProjectEventVoteCounts.rebuild!" do
      expect(Guidelines::ProjectEventVoteCounts).to receive(:rebuild!).and_call_original
      described_class.rebuild_vote_counts!
    end
  end
end
