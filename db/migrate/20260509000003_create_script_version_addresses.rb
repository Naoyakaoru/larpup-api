class CreateScriptVersionAddresses < ActiveRecord::Migration[7.1]
  def change
    create_table :script_version_addresses do |t|
      t.references :script_version, null: false, foreign_key: true
      t.references :address, null: false, foreign_key: true
    end

    add_index :script_version_addresses, [ :script_version_id, :address_id ], unique: true
  end
end
