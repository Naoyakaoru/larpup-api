class MakeScriptVersionStoreNullable < ActiveRecord::Migration[7.2]
  def change
    change_column_null :script_versions, :store_id, true
  end
end
