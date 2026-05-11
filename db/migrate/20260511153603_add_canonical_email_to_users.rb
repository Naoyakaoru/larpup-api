class AddCanonicalEmailToUsers < ActiveRecord::Migration[7.2]
  def up
    add_column :users, :canonical_email, :string

    User.reset_column_information
    User.find_each do |user|
      next if user.email.blank?
      user.update_column(:canonical_email, User.canonicalize_email(user.email))
    end

    change_column_null :users, :canonical_email, false
    add_index :users, :canonical_email, unique: true
  end

  def down
    remove_index :users, :canonical_email
    remove_column :users, :canonical_email
  end
end
