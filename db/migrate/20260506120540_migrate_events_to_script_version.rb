class MigrateEventsToScriptVersion < ActiveRecord::Migration[7.2]
  def up
    add_column :events, :script_version_id, :bigint
    add_column :events, :price_per_person, :integer

    # Create base version (store_id: null) for each existing script
    execute <<~SQL
      INSERT INTO script_versions (script_id, store_id, available, created_at, updated_at)
      SELECT id, NULL, true, NOW(), NOW()
      FROM scripts
    SQL

    # Point existing events to their script's base version
    execute <<~SQL
      UPDATE events
      SET script_version_id = sv.id
      FROM script_versions sv
      WHERE sv.script_id = events.script_id
        AND sv.store_id IS NULL
    SQL

    add_index :events, :script_version_id
    add_foreign_key :events, :script_versions
    change_column_null :events, :script_version_id, false
    remove_column :events, :script_id
  end

  def down
    add_column :events, :script_id, :bigint
    execute <<~SQL
      UPDATE events
      SET script_id = sv.script_id
      FROM script_versions sv
      WHERE sv.id = events.script_version_id
    SQL
    remove_foreign_key :events, :script_versions
    remove_column :events, :script_version_id
    remove_column :events, :price_per_person
  end
end
