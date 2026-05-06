class AddDeletedAtToEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :deleted_at, :datetime
  end
end
