class AddStatusToScripts < ActiveRecord::Migration[7.2]
  def change
    add_column :scripts, :status, :string, null: false, default: "approved"
  end
end
