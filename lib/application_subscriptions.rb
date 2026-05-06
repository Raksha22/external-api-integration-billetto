# frozen_string_literal: true

# Wire Rails Event Store subscribers from domain modules (Developer's Guide merge point).
class ApplicationSubscriptions
  # Each value: { handler: -> { #<callable> }, to: [FactClass, ...] }
  def self.handlers
    top_level_subscriptions.merge(Guidelines.subscriptions)
  end

  def self.top_level_subscriptions
    {}
  end

  def self.subscribe_rails_event_store!(event_store)
    handlers.each_value do |spec|
      event_store.subscribe(spec.fetch(:handler).call, to: spec.fetch(:to))
    end
  end
end
