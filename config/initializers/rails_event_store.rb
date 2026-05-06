# frozen_string_literal: true

Rails.application.config.to_prepare do
  store = RailsEventStore::Client.new
  ApplicationSubscriptions.subscribe_rails_event_store!(store)
  Rails.configuration.event_store = store
end
