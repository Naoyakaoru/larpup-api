class AddDurationToScripts < ActiveRecord::Migration[7.2]
  def change
    add_column :scripts, :duration, :decimal, precision: 3, scale: 1
  end
end
