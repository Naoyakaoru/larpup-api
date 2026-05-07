class AddPublisherToScripts < ActiveRecord::Migration[7.2]
  def change
    add_column :scripts, :publisher, :string
  end
end
