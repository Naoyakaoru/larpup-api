class AddCrossGenderFields < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :allow_cross_gender, :boolean, default: false, null: false
    add_column :event_members, :cross_gender, :boolean, default: false, null: false
  end
end
