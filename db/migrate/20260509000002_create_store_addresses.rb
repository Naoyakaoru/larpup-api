class CreateStoreAddresses < ActiveRecord::Migration[7.1]
  def change
    create_table :store_addresses do |t|
      t.references :store, null: false, foreign_key: true
      t.references :address, null: false, foreign_key: true
    end

    add_index :store_addresses, [ :store_id, :address_id ], unique: true
  end
end
