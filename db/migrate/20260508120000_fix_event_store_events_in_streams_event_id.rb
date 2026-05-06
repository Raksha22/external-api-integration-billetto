# frozen_string_literal: true

# Earlier migration incorrectly used bigint event_id -> event_store_events.id.
# RES expects string UUID event_id -> event_store_events.event_id (see EventInStream model).

class FixEventStoreEventsInStreamsEventId < ActiveRecord::Migration[7.1]
  def up
    return unless table_exists?(:event_store_events_in_streams)

    col = connection.columns(:event_store_events_in_streams).find { |c| c.name == "event_id" }
    return if col.nil?
    return unless col.sql_type == "bigint"

    drop_table :event_store_events_in_streams

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

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
