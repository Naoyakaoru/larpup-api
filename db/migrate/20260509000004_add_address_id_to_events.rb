class AddAddressIdToEvents < ActiveRecord::Migration[7.1]
  def change
    add_reference :events, :address, null: true, foreign_key: true
  end
end
