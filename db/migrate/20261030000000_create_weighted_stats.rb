class CreateWeightedStats < ActiveRecord::Migration[6.1]
  def change
    create_table :weighted_stats do |t|
      t.string  :hunt_code, null: false
      t.boolean :resident, null: false
      t.boolean :adult, null: false, default: true
      t.integer :preference_points, null: false
      t.integer :weighted_points, null: false
      t.integer :applicants, null: false, default: 0
      t.integer :success, null: false, default: 0
      t.timestamps
    end

    add_index :weighted_stats, :hunt_code
    add_index :weighted_stats,
              [:hunt_code, :resident, :adult, :preference_points, :weighted_points],
              unique: true, name: "index_weighted_stats_unique_key"
  end
end
