# frozen_string_literal: true

require "json"

module Billetto
  class Client
    class MissingApiKeyError < Error; end
    class RequestFailedError < Error; end
    class InvalidResponseError < Error; end

    DEFAULT_BASE_URL = "https://billetto.dk".freeze
    DEFAULT_EVENTS_PATH = "/api/v3/public/events".freeze

    def initialize(connection: nil)
      pair = api_keypair_value
      raise MissingApiKeyError, missing_keypair_message if pair.blank?

      @connection = connection || build_connection(pair)
    end

    def list_public_events(limit: 50)
      limit = [[limit.to_i, 1].max, 100].min
      response = connection.get(events_path, limit: limit)
      unless response.success?
        detail = response.body.to_s.truncate(300)
        raise RequestFailedError,
              "Billetto API responded with #{response.status} (#{request_url}) — #{detail}"
      end

      parsed = JSON.parse(response.body)
      extract_events(parsed)
    rescue Faraday::Error => e
      raise RequestFailedError, "Billetto API request failed: #{e.message}"
    rescue JSON::ParserError => e
      raise InvalidResponseError, "Billetto API returned invalid JSON: #{e.message}"
    end

    private

    attr_reader :connection

    def request_url
      base = ENV.fetch("BILLETTO_API_BASE_URL", DEFAULT_BASE_URL)
      "#{base}#{events_path}"
    end

    def build_connection(api_keypair)
      Faraday.new(url: ENV.fetch("BILLETTO_API_BASE_URL", DEFAULT_BASE_URL)) do |faraday|
        faraday.headers["Api-Keypair"] = api_keypair
        faraday.headers["Accept"] = "application/json"
        if (version = ENV["BILLETTO_VERSION"].presence)
          faraday.headers["Billetto-Version"] = version
        end
        faraday.options.timeout = 10
        faraday.options.open_timeout = 5
      end
    end

    def events_path
      ENV.fetch("BILLETTO_EVENTS_PATH", DEFAULT_EVENTS_PATH)
    end

    def api_keypair_value
      pair = strip_wrapping_quotes(ENV["BILLETTO_API_KEYPAIR"].to_s.strip)
      return pair if pair.include?(":")

      key = first_present_env("BILLETTO_API_ACCESS_KEY", "BILLETTO_API_KEY_ID", "BILLETTO_PUBLIC_KEY")
      secret = first_present_env("BILLETTO_API_SECRET", "BILLETTO_SECRET_KEY")

      secret ||= strip_wrapping_quotes(ENV["BILLETTO_API_KEY"].to_s.strip) if key.present?
      return "#{key}:#{secret}" if key.present? && secret.present?

      combined = strip_wrapping_quotes(ENV["BILLETTO_API_KEY"].to_s.strip)
      return combined if combined.include?(":")

      nil
    end

    def first_present_env(*names)
      names.each do |name|
        v = strip_wrapping_quotes(ENV[name].to_s.strip)
        return v if v.present?
      end
      nil
    end

    def strip_wrapping_quotes(value)
      return value if value.length < 2

      if (value.start_with?('"') && value.end_with?('"')) || (value.start_with?("'") && value.end_with?("'"))
        return value[1..-2]
      end

      value
    end

    def missing_keypair_message
      msg = +<<~TEXT.squish
        Billetto auth missing. The API expects header Api-Keypair = key:secret (both values from Integrate → Developers).
        Use BILLETTO_API_KEYPAIR=key:secret, or set BILLETTO_API_ACCESS_KEY plus BILLETTO_API_SECRET (or put the secret in BILLETTO_API_KEY).
      TEXT

      single = strip_wrapping_quotes(ENV["BILLETTO_API_KEY"].to_s.strip)
      if single.present? && !single.include?(":") && ENV["BILLETTO_API_ACCESS_KEY"].to_s.strip.blank?
        msg << " You currently have only BILLETTO_API_KEY (one value); add the other half as BILLETTO_API_ACCESS_KEY or combine both in BILLETTO_API_KEYPAIR."
      end

      msg << " https://api.billetto.com/docs/obtaining-an-api-key"
      msg
    end

    def extract_events(parsed_body)
      return parsed_body.fetch("events") if parsed_body.is_a?(Hash) && parsed_body["events"].is_a?(Array)
      return parsed_body.fetch("data") if parsed_body.is_a?(Hash) && parsed_body["data"].is_a?(Array)
      return parsed_body if parsed_body.is_a?(Array)

      raise InvalidResponseError, "Unable to locate events list in API response"
    end
  end
end
