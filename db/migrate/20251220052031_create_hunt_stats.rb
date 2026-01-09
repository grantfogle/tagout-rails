class CreateHuntStats < ActiveRecord::Migration[6.1]
  def change
    create_table :hunt_stats do |t|
      t.string :hunt_code
      t.string :state
      t.string :species
      t.string :sex
      t.string :unit
      t.string :season
      t.string :method
      t.boolean :resident
      t.boolean :adult
      t.string :draw_type
      t.integer :value
      t.integer :applicants
      t.integer :success

      t.timestamps
    end
  end
end
