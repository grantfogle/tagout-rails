class CreateCalendarEvents < ActiveRecord::Migration[6.1]
  def change
    create_table :calendar_events do |t|
      t.string :title, null: false
      t.string :kind, null: false
      t.string :state, null: false, default: "CO"
      t.string :species
      t.date :starts_on, null: false
      t.date :ends_on
      t.references :user, foreign_key: true, null: true
      t.text :notes
      t.timestamps
    end
    add_index :calendar_events, :starts_on
  end
end
