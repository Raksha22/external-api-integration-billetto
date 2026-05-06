# frozen_string_literal: true

module Guidelines
  def self.subscriptions
    [].map(&:subscriptions).inject({}, :merge)
  end
end
