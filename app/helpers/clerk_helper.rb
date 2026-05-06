# frozen_string_literal: true

module ClerkHelper
  # Frontend API origin (https://…​) derived from CLERK_PUBLISHABLE_KEY — required to load Clerk JS from the correct instance.
  def clerk_frontend_api_origin
    pk = ENV["CLERK_PUBLISHABLE_KEY"].to_s
    return if pk.blank?

    host = Clerk::Utils.decode_publishable_key(pk).chomp("$")
    "https://#{host}"
  rescue ArgumentError
    nil
  end

  def clerk_publishable_key_for_js
    ENV["CLERK_PUBLISHABLE_KEY"].presence
  end
end
