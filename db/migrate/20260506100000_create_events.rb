class CreateEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :events do |t|
      t.string :external_id, null: false
      t.string :title, null: false
      t.datetime :starts_at, null: false
      t.string :image_url
      t.text :description
      t.string :venue_name
      t.jsonb :raw_payload, null: false, default: {}

      t.timestamps
    end

    add_index :events, :external_id, unique: true
    add_index :events, :starts_at
  end
end
