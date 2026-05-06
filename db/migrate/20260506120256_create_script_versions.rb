class CreateScriptVersions < ActiveRecord::Migration[7.2]
  def change
    create_table :script_versions do |t|
      t.references :script, null: false, foreign_key: true
      t.references :store, null: true, foreign_key: true
      t.string :version_name
      t.integer :price
      t.boolean :available, default: true, null: false
      t.decimal :duration_override, precision: 3, scale: 1

      t.timestamps
    end
  end
end
