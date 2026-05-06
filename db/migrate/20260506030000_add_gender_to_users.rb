class AddGenderToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :gender, :string, null: false, default: "other"
  end
end
