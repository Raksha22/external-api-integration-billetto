# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Event voting (browser)", type: :system do
  let!(:event) do
    Guidelines::Event.create!(
      external_id: "browser_vote_evt",
      title: "Browser Vote Event",
      starts_at: 1.day.from_now,
      upvotes_count: 0,
      downvotes_count: 0
    )
  end

  scenario "guest cannot vote and is sent toward Clerk sign-in" do
    visit root_path

    expect(page).to have_content("Browser Vote Event")
    expect(page).to have_link("Sign in")
    expect(page).to have_link("sign up")
    expect(page).not_to have_button("Like")

    # Guests never see vote buttons; forcing POST still hits the Clerk gate (same as clicking Like when signed in).
    page.driver.submit :post, event_vote_path(event), direction: "up"

    expect(page.current_url).to start_with(ENV.fetch("CLERK_SIGN_IN_URL").split("?").first)
  end

  scenario "signed-in user votes like and sees flash plus updated totals" do
    clerk_double = double(
      "clerk",
      user?: true,
      user_id: "browser_voter",
      session: { "sub" => "browser_voter" },
      sign_in_url: nil,
      sign_up_url: nil,
      sign_out_url: nil
    )

    allow_any_instance_of(ApplicationController).to receive(:clerk).and_return(clerk_double)

    visit root_path

    expect(page).to have_content("Browser Vote Event")
    expect(page).to have_content("0 like")
    expect(page).to have_content("0 dislike")

    click_button "Like"

    expect(page).to have_current_path(events_path, ignore_query: true)
    expect(page).to have_content("Vote recorded.")
    expect(page).to have_content("1 like")
    expect(page).to have_content("0 dislike")

    click_button "Dislike"

    expect(page).to have_content("Vote recorded.")
    expect(page).to have_content("1 like")
    expect(page).to have_content("1 dislike")
  end
end
