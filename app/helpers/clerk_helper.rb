# frozen_string_literal: true

module ClerkHelper
  # Frontend API origin (https://…​) derived from CLERK_PUBLISHABLE_KEY — required to load Clerk JS from the correct instance.
  def clerk_frontend_api_origin
    pk = ENV["CLERK_PUBLISHABLE_KEY"].to_s
    return if pk.blank?

    host = Clerk::Utils.decode_publishable_key(pk).chomp("$").to_s
    # Dummy publishable keys in test decode to bytes that are not valid UTF-8 labels.
    ("https://#{host}").b.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
  rescue ArgumentError
    nil
  end

  def clerk_publishable_key_for_js
    ENV["CLERK_PUBLISHABLE_KEY"].presence&.yield_self do |s|
      s.to_s.b.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    end
  end
end
