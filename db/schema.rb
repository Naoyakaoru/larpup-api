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

ActiveRecord::Schema[7.2].define(version: 2026_05_06_020359) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "event_members", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "user_id", null: false
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "user_id"], name: "index_event_members_on_event_id_and_user_id", unique: true
    t.index ["event_id"], name: "index_event_members_on_event_id"
    t.index ["user_id"], name: "index_event_members_on_user_id"
  end

  create_table "events", force: :cascade do |t|
    t.bigint "script_id", null: false
    t.bigint "host_id", null: false
    t.datetime "scheduled_at"
    t.string "location"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["host_id"], name: "index_events_on_host_id"
    t.index ["script_id"], name: "index_events_on_script_id"
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
    t.index ["genres"], name: "index_scripts_on_genres", using: :gin
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.string "nickname"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "event_members", "events"
  add_foreign_key "event_members", "users"
  add_foreign_key "events", "scripts"
  add_foreign_key "events", "users", column: "host_id"
end
