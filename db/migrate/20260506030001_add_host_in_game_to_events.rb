class AddHostInGameToEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :host_in_game, :boolean, default: false, null: false
  end
end
