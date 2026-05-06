class CreateStores < ActiveRecord::Migration[7.2]
  def change
    create_table :stores do |t|
      t.string :name, null: false
      t.string :status, default: "active", null: false

      t.timestamps
    end
  end
end
