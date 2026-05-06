# frozen_string_literal: true

module Guidelines
  class SyncPublicEvents
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :limit, :integer, default: 50

    validates :limit, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  end
end
