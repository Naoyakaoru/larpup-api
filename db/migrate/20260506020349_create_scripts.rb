class CreateScripts < ActiveRecord::Migration[7.2]
  def change
    create_table :scripts do |t|
      t.string :title
      t.integer :genres, array: true, default: []
      t.text :description
      t.integer :difficulty
      t.integer :male_slots
      t.integer :female_slots
      t.integer :any_slots

      t.timestamps
    end
    add_index :scripts, :genres, using: :gin
  end
end
