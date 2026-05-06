# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Clerk authentication (browser)", type: :system do
  scenario "guest sees sign-in and sign-up links to Account Portal URLs" do
    visit root_path

    expect(page).to have_link("Sign in", href: %r{\A#{Regexp.escape(ENV.fetch('CLERK_SIGN_IN_URL'))}})
    expect(page).to have_link("Sign up", href: %r{\A#{Regexp.escape(ENV.fetch('CLERK_SIGN_UP_URL'))}})
    expect(find_link("Sign in")[:href]).to include("redirect_url=")
    expect(find_link("Sign up")[:href]).to include("redirect_url=")
  end

  scenario "signed-in user sees identity and sign-out to Account Portal" do
    clerk_double = double(
      "clerk",
      user?: true,
      user_id: "system_spec_user",
      session: { "sub" => "system_spec_user" },
      sign_in_url: nil,
      sign_up_url: nil,
      sign_out_url: nil
    )

    allow_any_instance_of(ApplicationController).to receive(:clerk).and_return(clerk_double)

    visit root_path

    expect(page).to have_content("Signed in")
    expect(page).to have_content("system_spec_user")

    sign_out = find_link("Sign out")
    expect(sign_out[:href]).to start_with(ENV.fetch("CLERK_SIGN_OUT_URL"))
    expect(sign_out[:href]).to include("redirect_url=")

    sign_out.click

    expect(page.current_url).to start_with(ENV.fetch("CLERK_SIGN_OUT_URL").split("?").first)
  end
end
