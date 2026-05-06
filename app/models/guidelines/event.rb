# frozen_string_literal: true

module Guidelines
  class Event < ApplicationRecord
    self.table_name = "events"

    include EventStoreInjector
    include HasTypeid

    has_typeid :event

    validates :external_id, presence: true, uniqueness: true
    validates :title, presence: true
    validates :starts_at, presence: true

    scope :ordered, -> { order(starts_at: :asc) }
  end
end
