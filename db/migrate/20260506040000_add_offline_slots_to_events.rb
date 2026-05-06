class AddOfflineSlotsToEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :offline_male, :integer, default: 0, null: false
    add_column :events, :offline_female, :integer, default: 0, null: false
  end
end
