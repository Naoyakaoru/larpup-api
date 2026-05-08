class AddDeletedAtToScriptVersions < ActiveRecord::Migration[7.2]
  def change
    add_column :script_versions, :deleted_at, :datetime
    add_index :script_versions, :deleted_at
  end
end
