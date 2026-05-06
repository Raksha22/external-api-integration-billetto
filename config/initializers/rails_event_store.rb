# frozen_string_literal: true

Rails.application.config.to_prepare do
  Rails.configuration.event_store = RailsEventStore::Client.new
end
