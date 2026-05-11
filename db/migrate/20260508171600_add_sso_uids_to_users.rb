class AddSsoUidsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :google_uid, :string
    add_column :users, :line_uid, :string
    add_index :users, :google_uid, unique: true
    add_index :users, :line_uid, unique: true
  end
end
