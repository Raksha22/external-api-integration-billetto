# frozen_string_literal: true

module EventStoreTestHelpers
  module_function

  def decode_event_store_data(raw)
    raw = raw.to_s
    if raw.start_with?("\\x")
      [raw.delete_prefix("\\x")].pack("H*").force_encoding(Encoding::UTF_8)
    elsif raw.encoding == Encoding::ASCII_8BIT
      raw.dup.force_encoding(Encoding::UTF_8)
    else
      raw
    end
  end
end

RSpec.configure do |config|
  config.include EventStoreTestHelpers
end
