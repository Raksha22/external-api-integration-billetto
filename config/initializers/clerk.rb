# frozen_string_literal: true

# https://clerk.com/docs/reference/ruby/rails
#
# Secret key resolution:
# - Production: encrypted credentials first (`clerk.secret_key`), then ENV as fallback.
# - Development / test: ENV `CLERK_SECRET_KEY` first (from `.env` via Dotenv), then credentials,
#   then a fixed test dummy in `test` only when both are blank (specs stub Clerk HTTP).
#
# Publishable key: always `ENV["CLERK_PUBLISHABLE_KEY"]` (set in `.env`).
Clerk.configure do |config|
  publishable_key = ENV["CLERK_PUBLISHABLE_KEY"].to_s.strip

  secret_key =
    if Rails.env.production?
      Rails.application.credentials.dig(:clerk, :secret_key).to_s.strip.presence ||
        ENV["CLERK_SECRET_KEY"].to_s.strip.presence
    else
      ENV["CLERK_SECRET_KEY"].to_s.strip.presence ||
        Rails.application.credentials.dig(:clerk, :secret_key).to_s.strip.presence ||
        (Rails.env.test? ? "sk_test_00000000000000000000000000000000" : nil)
    end

  if secret_key.blank?
    raise <<~MSG.squish
      Missing Clerk secret key. For development add `CLERK_SECRET_KEY=sk_test_…` to `.env`, or run
      `EDITOR=nano bin/rails credentials:edit` and set `clerk.secret_key`. Use the Secret key from
      Clerk Dashboard → API keys (same application as your publishable key).
    MSG
  end

  unless secret_key.start_with?("sk_test_", "sk_live_")
    hint =
      if publishable_key.start_with?("pk_") && secret_key == publishable_key
        " Use the Secret key row in Clerk, not the Publishable key."
      elsif secret_key.start_with?("pk_")
        " Value looks like a Publishable key (pk_…); Secret keys start with sk_."
      else
        ""
      end

    raise("Invalid Clerk secret key." + hint)
  end

  unless publishable_key.start_with?("pk_test_", "pk_live_")
    raise <<~MSG.squish
      CLERK_PUBLISHABLE_KEY must start with pk_test_ or pk_live_ (set in .env from Clerk Dashboard → API keys).
    MSG
  end

  config.secret_key = secret_key
  config.publishable_key = publishable_key
end
