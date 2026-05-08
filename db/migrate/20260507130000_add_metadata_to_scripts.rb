class AddMetadataToScripts < ActiveRecord::Migration[7.2]
  def change
    add_column :scripts, :metadata, :jsonb, default: {}, null: false
  end
end
