class AddHostCrossGenderToEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :host_cross_gender, :boolean, default: false, null: false
  end
end
