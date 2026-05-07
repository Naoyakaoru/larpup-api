class AddUniqueTitleToScripts < ActiveRecord::Migration[7.2]
  def change
    add_index :scripts, :title, unique: true
  end
end
