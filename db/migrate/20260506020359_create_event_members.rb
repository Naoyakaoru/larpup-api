class CreateEventMembers < ActiveRecord::Migration[7.2]
  def change
    create_table :event_members do |t|
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :status

      t.timestamps
    end
    add_index :event_members, [ :event_id, :user_id ], unique: true
  end
end
