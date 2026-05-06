# frozen_string_literal: true

module Guidelines
  class RecordEventVote
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :event_external_id, :string
    attribute :clerk_user_id, :string
    attribute :direction, :string

    validates :event_external_id, :clerk_user_id, :direction, presence: true
    validates :direction, inclusion: { in: %w[up down] }

    def up?
      direction.to_s == "up"
    end
  end
end
