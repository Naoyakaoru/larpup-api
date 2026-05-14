class CreateUserConsents < ActiveRecord::Migration[7.2]
  def change
    create_table :user_consents do |t|
      t.references :user, null: false, foreign_key: true, index: true

      t.string  :consent_type,    null: false, limit: 50
      t.string  :consent_version, null: false, limit: 50
      t.boolean :accepted,        null: false, default: true
      t.datetime :accepted_at,   null: false, default: -> { "CURRENT_TIMESTAMP" }

      t.string :ip_address, limit: 255
      t.text   :user_agent
      t.string :source, limit: 50
    end

    add_index :user_consents, :consent_type
    add_index :user_consents, [ :user_id, :consent_type, :consent_version ],
              unique: true,
              name: "index_user_consents_on_user_type_version"
  end
end

