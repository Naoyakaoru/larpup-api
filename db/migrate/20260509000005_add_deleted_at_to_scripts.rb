class AddDeletedAtToScripts < ActiveRecord::Migration[7.1]
  def change
    add_column :scripts, :deleted_at, :datetime
    add_index :scripts, :deleted_at
  end
end
