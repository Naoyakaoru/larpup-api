class CreateAddresses < ActiveRecord::Migration[7.1]
  def change
    create_table :addresses do |t|
      t.string :name, null: false
      t.string :address
      t.string :map_url
      t.string :region, null: false
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :addresses, :name, unique: true
    add_index :addresses, :deleted_at
  end
end
