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

ActiveRecord::Schema[8.0].define(version: 2025_06_24_164443) do
  create_table "array_nodes", force: :cascade do |t|
    t.string "value_type", null: false
    t.integer "value_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["value_type", "value_id"], name: "index_array_nodes_on_value"
  end

  create_table "endpoints", force: :cascade do |t|
    t.integer "http_verb", null: false
    t.string "url", null: false
    t.integer "version_id", null: false
    t.string "input_type", null: false
    t.integer "input_id", null: false
    t.string "output_type", null: false
    t.integer "output_id", null: false
    t.string "original_input_string", null: false
    t.string "original_output_string", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["input_type", "input_id"], name: "index_endpoints_on_input"
    t.index ["output_type", "output_id"], name: "index_endpoints_on_output"
    t.index ["version_id"], name: "index_endpoints_on_version_id"
  end

  create_table "entities", force: :cascade do |t|
    t.string "name"
    t.integer "version_id", null: false
    t.string "root_type", null: false
    t.integer "root_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["root_type", "root_id"], name: "index_entities_on_root"
    t.index ["version_id", "name"], name: "index_entities_on_version_id_and_name", unique: true
    t.index ["version_id"], name: "index_entities_on_version_id"
  end

  create_table "entity_nodes", force: :cascade do |t|
    t.integer "entity_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_id"], name: "index_entity_nodes_on_entity_id"
  end

  create_table "groups", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "nothing_nodes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "object_attributes", force: :cascade do |t|
    t.string "name", null: false
    t.integer "order", null: false
    t.string "value_type", null: false
    t.integer "value_id", null: false
    t.integer "parent_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_object_attributes_on_parent_id"
    t.index ["value_type", "value_id"], name: "index_object_attributes_on_value"
  end

  create_table "object_nodes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "primitive_nodes", force: :cascade do |t|
    t.integer "kind", null: false
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "group_id", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["group_id"], name: "index_users_on_group_id"
  end

  create_table "versions", force: :cascade do |t|
    t.string "name", null: false
    t.integer "order", null: false
    t.integer "project_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "name"], name: "index_versions_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_versions_on_project_id"
  end

  add_foreign_key "endpoints", "versions"
  add_foreign_key "entities", "versions"
  add_foreign_key "entity_nodes", "entities"
  add_foreign_key "object_attributes", "object_nodes", column: "parent_id"
  add_foreign_key "projects", "groups"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "groups"
  add_foreign_key "versions", "projects"
end
