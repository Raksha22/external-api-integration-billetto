# frozen_string_literal: true

# Wire async/event subscriptions from domain modules and integrators (Developer's Guide).
class ApplicationSubscriptions
  def self.handlers
    top_level_subscriptions
      .merge(Guidelines.subscriptions)
  end

  def self.top_level_subscriptions
    {}
  end
end
