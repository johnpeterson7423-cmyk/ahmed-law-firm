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

ActiveRecord::Schema[7.2].define(version: 2026_07_28_203635) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "checkup_results", force: :cascade do |t|
    t.bigint "checkup_run_id", null: false
    t.string "client", default: "", null: false
    t.string "dol", default: "", null: false
    t.string "last_checkup_date"
    t.string "status", default: "not_found", null: false
    t.string "document_name"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "needs_to_call", default: false, null: false
    t.index ["checkup_run_id", "needs_to_call"], name: "index_checkup_results_on_checkup_run_id_and_needs_to_call"
    t.index ["checkup_run_id", "status"], name: "index_checkup_results_on_checkup_run_id_and_status"
    t.index ["checkup_run_id"], name: "index_checkup_results_on_checkup_run_id"
  end

  create_table "checkup_runs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "status", default: "pending", null: false
    t.integer "limit_count", default: 25, null: false
    t.integer "total", default: 0, null: false
    t.integer "scanned", default: 0, null: false
    t.integer "found_count", default: 0, null: false
    t.integer "not_found_count", default: 0, null: false
    t.string "query"
    t.string "insurance"
    t.string "filter_status"
    t.string "last_client"
    t.text "error"
    t.jsonb "clients_payload", default: [], null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "created_at"], name: "index_checkup_runs_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_checkup_runs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "google_uid", null: false
    t.text "access_token"
    t.text "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["google_uid"], name: "index_users_on_google_uid", unique: true
  end

  add_foreign_key "checkup_results", "checkup_runs"
  add_foreign_key "checkup_runs", "users"
end
