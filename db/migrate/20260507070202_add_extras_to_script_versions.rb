class AddExtrasToScriptVersions < ActiveRecord::Migration[7.2]
  def change
    add_column :script_versions, :extras, :jsonb, default: {}, null: false
  end
end
