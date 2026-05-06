# frozen_string_literal: true

module EventStoreInjector
  extend ActiveSupport::Concern

  def event_store
    Rails.configuration.event_store
  end
end
