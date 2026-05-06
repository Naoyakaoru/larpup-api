class CreateEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :events do |t|
      t.references :script, null: false, foreign_key: true
      t.references :host, null: false, foreign_key: { to_table: :users }
      t.datetime :scheduled_at
      t.string :location
      t.integer :status

      t.timestamps
    end
  end
end
