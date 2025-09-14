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

ActiveRecord::Schema[8.0].define(version: 2025_07_23_162601) do
  create_table "candidates", force: :cascade do |t|
    t.string "name"
    t.integer "order"
    t.integer "project_id", null: false
    t.string "aasm_state", default: "open", null: false
    t.integer "base_version_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["base_version_id"], name: "index_candidates_on_base_version_id"
    t.index ["project_id"], name: "index_candidates_on_project_id"
  end

  create_table "endpoints", force: :cascade do |t|
    t.integer "http_verb", null: false
    t.string "path", null: false
    t.integer "version_id", null: false
    t.string "output", null: false
    t.string "output_error", null: false
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["version_id"], name: "index_endpoints_on_version_id"
  end

  create_table "entities", force: :cascade do |t|
    t.string "name"
    t.integer "version_id", null: false
    t.string "root"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["version_id", "name"], name: "index_entities_on_version_id_and_name", unique: true
    t.index ["version_id"], name: "index_entities_on_version_id"
  end

  create_table "groups", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "group_id", null: false
    t.index ["group_id", "name"], name: "index_projects_on_group_id_and_name", unique: true
    t.index ["group_id"], name: "index_projects_on_group_id"
  end

  create_table "responses", force: :cascade do |t|
    t.string "code", null: false
    t.string "note"
    t.integer "endpoint_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint_id", "code"], name: "index_responses_on_endpoint_id_and_code", unique: true
    t.index ["endpoint_id"], name: "index_responses_on_endpoint_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "group_id", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["group_id"], name: "index_users_on_group_id"
  end

  create_table "versions", force: :cascade do |t|
    t.string "name", null: false
    t.integer "order", null: false
    t.integer "project_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "candidate_id"
    t.index ["candidate_id"], name: "index_versions_on_candidate_id"
    t.index ["project_id", "name"], name: "index_versions_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_versions_on_project_id"
  end

  add_foreign_key "candidates", "projects"
  add_foreign_key "candidates", "versions", column: "base_version_id"
  add_foreign_key "endpoints", "versions"
  add_foreign_key "entities", "versions"
  add_foreign_key "projects", "groups"
  add_foreign_key "responses", "endpoints"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "groups"
  add_foreign_key "versions", "candidates"
  add_foreign_key "versions", "projects"
end
