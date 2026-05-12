class ChangeUsersGenderDefault < ActiveRecord::Migration[7.2]
  def change
    change_column_default :users, :gender, from: "other", to: nil
  end
end
