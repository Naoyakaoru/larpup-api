class AddHandleToUsers < ActiveRecord::Migration[7.2]
  def up
    add_column :users, :handle, :string

    User.find_each do |user|
      loop do
        candidate = "user#{SecureRandom.alphanumeric(6).downcase}"
        unless User.exists?(handle: candidate)
          user.update_column(:handle, candidate)
          break
        end
      end
    end

    change_column_null :users, :handle, false
    add_index :users, :handle, unique: true
  end

  def down
    remove_column :users, :handle
  end
end
