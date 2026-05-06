require "rails_helper"

RSpec.describe "Event votes", type: :request do
  let!(:event) do
    Guidelines::Event.create!(
      external_id: "vote_spec_evt",
      title: "Vote Spec Event",
      starts_at: 1.day.from_now
    )
  end

  describe "POST /events/:event_id/vote" do
    context "when not signed in with Clerk" do
      before do
        allow_any_instance_of(EventVotesController).to receive(:clerk).and_return(
          double("clerk", user?: false, user_id: nil, session: nil, sign_in_url: nil)
        )
      end

      it "redirects to sign-in and does not append vote facts" do
        expect do
          post event_vote_path(event), params: { direction: "up" }
        end.not_to(change do
          ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM event_store_events")
        end)

        expect(response).to have_http_status(:redirect)
        expect(response.location).to start_with(ENV.fetch("CLERK_SIGN_IN_URL"))
      end
    end

    context "when signed in with Clerk" do
      before do
        allow_any_instance_of(EventVotesController).to receive(:clerk).and_return(
          double(
            "clerk",
            user?: true,
            user_id: "user_test_vote",
            session: { "sub" => "user_test_vote" },
            sign_in_url: nil
          )
        )
      end

      it "records EventUpvoted in Rails Event Store with clerk user id" do
        expect do
          post event_vote_path(event), params: { direction: "up" }
        end.to(change do
          ActiveRecord::Base.connection.select_value(
            "SELECT COUNT(*) FROM event_store_events WHERE event_type LIKE '%EventUpvoted%'"
          ).to_i
        end.by(1))

        row = ActiveRecord::Base.connection.select_one(
          "SELECT data FROM event_store_events WHERE event_type LIKE '%EventUpvoted%' ORDER BY id DESC LIMIT 1"
        )
        payload = decode_event_store_data(row["data"])

        expect(payload).to include("user_test_vote")
        expect(payload).to include("vote_spec_evt")

        expect(response).to redirect_to(events_path)
      end

      it "records EventDownvoted for direction down" do
        expect do
          post event_vote_path(event), params: { direction: "down" }
        end.to(change do
          ActiveRecord::Base.connection.select_value(
            "SELECT COUNT(*) FROM event_store_events WHERE event_type LIKE '%EventDownvoted%'"
          ).to_i
        end.by(1))
      end

      it "does not append facts and redirects with alert when direction is invalid" do
        expect do
          post event_vote_path(event), params: { direction: "sideways" }
        end.not_to(change do
          ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM event_store_events").to_i
        end)

        expect(response).to redirect_to(events_path)
        follow_redirect!
        expect(response.body).to match(/Direction is not included/)
      end

      it "does not append facts when direction is missing" do
        expect do
          post event_vote_path(event)
        end.not_to(change do
          ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM event_store_events").to_i
        end)

        expect(response).to redirect_to(events_path)
      end
    end

    context "when signed in but event does not exist" do
      before do
        allow_any_instance_of(EventVotesController).to receive(:clerk).and_return(
          double(
            "clerk",
            user?: true,
            user_id: "user_test_vote",
            session: { "sub" => "user_test_vote" },
            sign_in_url: nil
          )
        )
      end

      it "redirects with alert and does not publish vote facts" do
        missing_id = (Guidelines::Event.maximum(:id) || 0) + 99_999

        expect do
          post event_vote_path(event_id: missing_id), params: { direction: "up" }
        end.not_to(change do
          ActiveRecord::Base.connection.select_value(
            "SELECT COUNT(*) FROM event_store_events WHERE event_type LIKE '%EventUpvoted%'"
          ).to_i
        end)

        expect(response).to redirect_to(events_path)
        follow_redirect!
        expect(response.body).to include("Event not found")
      end
    end
  end
end
