class CreateProfilesAndPreferencePoints < ActiveRecord::Migration[6.1]
  def change
    create_table :profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :name, null: false
      t.string :residency_state
      t.boolean :resident
      t.string :favorite_species, array: true, default: [], null: false
      t.string :states_of_interest, array: true, default: [], null: false
      t.string :preferred_methods, array: true, default: [], null: false
      t.boolean :notifications_enabled, default: false, null: false
      t.timestamps
    end

    create_table :preference_points do |t|
      t.references :profile, null: false, foreign_key: true
      t.string :species, null: false
      t.integer :points, null: false
      t.timestamps
    end
    add_index :preference_points, [:profile_id, :species], unique: true
  end
end
