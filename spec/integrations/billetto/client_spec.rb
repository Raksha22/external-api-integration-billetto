# frozen_string_literal: true

require "rails_helper"

RSpec.describe Billetto::Client do
  around do |example|
    @env_backup = ENV.to_hash
    ENV.replace(@env_backup.merge("BILLETTO_API_KEYPAIR" => "test_access:test_secret"))
    example.run
  ensure
    ENV.replace(@env_backup)
  end

  describe "#initialize" do
    it "raises MissingApiKeyError when no key material is configured" do
      ENV.delete("BILLETTO_API_KEYPAIR")

      expect { described_class.new }.to raise_error(Billetto::Client::MissingApiKeyError)
    end
  end

  describe "#list_public_events" do
    def client_with_response(status:, body:)
      response = instance_double(Faraday::Response, success?: status.between?(200, 299), status: status, body: body)
      connection = instance_double(Faraday::Connection)
      allow(connection).to receive(:get).and_return(response)
      described_class.new(connection: connection)
    end

    it "returns events from a top-level array JSON body" do
      client = client_with_response(status: 200, body: [{ "id" => "1", "title" => "A", "starts_at" => "2026-01-01T12:00:00Z" }].to_json)
      expect(client.list_public_events(limit: 10).size).to eq(1)
    end

    it "unwraps { \"events\" => [...] }" do
      client = client_with_response(status: 200, body: { "events" => [{ "id" => "1", "title" => "A", "starts_at" => "2026-01-01T12:00:00Z" }] }.to_json)
      expect(client.list_public_events(limit: 10).first["id"]).to eq("1")
    end

    it "unwraps { \"data\" => [...] }" do
      client = client_with_response(status: 200, body: { "data" => [{ "id" => "1", "title" => "A", "starts_at" => "2026-01-01T12:00:00Z" }] }.to_json)
      expect(client.list_public_events(limit: 10).first["id"]).to eq("1")
    end

    it "raises RequestFailedError on non-success HTTP status" do
      client = client_with_response(status: 401, body: '{"error":"auth"}')
      expect { client.list_public_events(limit: 10) }.to raise_error(Billetto::Client::RequestFailedError, /401/)
    end

    it "raises InvalidResponseError on malformed JSON" do
      client = client_with_response(status: 200, body: "not json")
      expect { client.list_public_events(limit: 10) }.to raise_error(Billetto::Client::InvalidResponseError)
    end

    it "raises InvalidResponseError when events collection cannot be located" do
      client = client_with_response(status: 200, body: { "meta" => {} }.to_json)
      expect { client.list_public_events(limit: 10) }.to raise_error(Billetto::Client::InvalidResponseError, /Unable to locate/)
    end

    it "clamps limit to 1..100 before requesting" do
      response = instance_double(Faraday::Response, success?: true, status: 200, body: [].to_json)
      connection = instance_double(Faraday::Connection)
      allow(connection).to receive(:get).with(anything, hash_including(limit: 100)).and_return(response)
      client = described_class.new(connection: connection)
      client.list_public_events(limit: 500)
    end
  end
end
