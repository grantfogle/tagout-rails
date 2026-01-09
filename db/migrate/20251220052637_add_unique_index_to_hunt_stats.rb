class AddUniqueIndexToHuntStats < ActiveRecord::Migration[6.1]
  def change
    add_index :hunt_stats,
      [:hunt_code, :resident, :adult, :draw_type, :value],
      unique: true,
      name: "index_hunt_stats_unique_key"
  end
end
