class RenameMethodToHuntMethodInHuntStats < ActiveRecord::Migration[6.1]
  def change
    rename_column :hunt_stats, :method, :hunt_method
  end
end