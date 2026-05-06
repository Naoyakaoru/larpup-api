class CreateAuditLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :audit_logs do |t|
      t.references :auditable, polymorphic: true, null: false, index: true
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.jsonb :metadata, default: {}

      t.timestamps
    end
  end
end
