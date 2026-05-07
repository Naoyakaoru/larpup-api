# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_05_07_070439) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "auditable_type", null: false
    t.bigint "auditable_id", null: false
    t.bigint "user_id", null: false
    t.string "action", null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "event_members", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "user_id", null: false
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "cross_gender", default: false, null: false
    t.datetime "confirmed_at"
    t.datetime "rejected_at"
    t.datetime "leave_requested_at"
    t.datetime "cancelled_at"
    t.index ["event_id", "user_id"], name: "index_event_members_on_event_id_and_user_id", unique: true
    t.index ["event_id"], name: "index_event_members_on_event_id"
    t.index ["user_id"], name: "index_event_members_on_user_id"
  end

  create_table "events", force: :cascade do |t|
    t.bigint "host_id", null: false
    t.datetime "scheduled_at"
    t.string "location"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "allow_cross_gender", default: false, null: false
    t.integer "offline_male", default: 0, null: false
    t.integer "offline_female", default: 0, null: false
    t.datetime "deleted_at"
    t.bigint "script_version_id"
    t.index ["host_id"], name: "index_events_on_host_id"
    t.index ["script_version_id"], name: "index_events_on_script_version_id"
  end

  create_table "script_versions", force: :cascade do |t|
    t.bigint "script_id", null: false
    t.bigint "store_id"
    t.string "version_name"
    t.integer "price"
    t.boolean "available"
    t.decimal "duration_override"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "extras", default: {}, null: false
    t.index ["script_id"], name: "index_script_versions_on_script_id"
    t.index ["store_id"], name: "index_script_versions_on_store_id"
  end

  create_table "scripts", force: :cascade do |t|
    t.string "title"
    t.integer "genres", default: [], array: true
    t.text "description"
    t.integer "difficulty"
    t.integer "male_slots"
    t.integer "female_slots"
    t.integer "any_slots"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "duration"
    t.string "status", default: "approved", null: false
    t.string "publisher"
    t.index ["genres"], name: "index_scripts_on_genres", using: :gin
  end

  create_table "stores", force: :cascade do |t|
    t.string "name"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "owner_id", null: false
    t.index ["owner_id"], name: "index_stores_on_owner_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.string "nickname"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_admin", default: false, null: false
    t.string "gender", default: "other", null: false
    t.boolean "show_hosted_events", default: false, null: false
    t.string "handle", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["handle"], name: "index_users_on_handle", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "event_members", "events"
  add_foreign_key "event_members", "users"
  add_foreign_key "events", "script_versions"
  add_foreign_key "events", "users", column: "host_id"
  add_foreign_key "script_versions", "scripts"
  add_foreign_key "script_versions", "stores"
  add_foreign_key "stores", "users", column: "owner_id"
end
