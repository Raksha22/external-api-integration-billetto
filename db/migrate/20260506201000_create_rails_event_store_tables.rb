# frozen_string_literal: true

# Matches ruby_event_store-active_record / Rails Event Store 2.x expectations:
# stream rows store the domain event UUID in event_id and FK to event_store_events.event_id
# (not the bigint primary key of event_store_events).
# See: bin/rails generate rails_event_store_active_record:migration

class CreateRailsEventStoreTables < ActiveRecord::Migration[7.1]
  def change
    create_table(:event_store_events, id: :bigserial, force: false) do |t|
      t.string :event_id, limit: 36, null: false
      t.string :event_type, null: false
      t.binary :metadata
      t.binary :data, null: false
      t.datetime :created_at, null: false, precision: 6
      t.datetime :valid_at, precision: 6
    end

    add_index :event_store_events, :event_id, unique: true
    add_index :event_store_events, :created_at
    add_index :event_store_events, :event_type

    create_table(:event_store_events_in_streams, id: :bigserial, force: false) do |t|
      t.string :stream, null: false
      t.integer :position, null: true
      t.string :event_id, limit: 36, null: false
      t.datetime :created_at, null: false, precision: 6
    end

    add_index :event_store_events_in_streams, %i[stream position], unique: true
    add_index :event_store_events_in_streams, %i[stream event_id], unique: true
    add_index :event_store_events_in_streams, :event_id

    add_foreign_key :event_store_events_in_streams, :event_store_events,
      column: :event_id,
      primary_key: :event_id
  end
end
