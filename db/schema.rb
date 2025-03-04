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

ActiveRecord::Schema[8.0].define(version: 2025_02_25_112217) do
  create_table "endpoints", force: :cascade do |t|
    t.integer "http_verb", null: false
    t.string "url", null: false
    t.integer "version_id", null: false
    t.string "endpoint_root_type", null: false
    t.integer "endpoint_root_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint_root_type", "endpoint_root_id"], name: "index_endpoints_on_endpoint_root"
    t.index ["version_id"], name: "index_endpoints_on_version_id"
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
  end

  create_table "versions", force: :cascade do |t|
    t.string "name", null: false
    t.integer "order", null: false
    t.integer "project_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_versions_on_project_id"
  end

  add_foreign_key "endpoints", "versions"
  add_foreign_key "object_attributes", "object_nodes", column: "parent_id"
  add_foreign_key "versions", "projects"
end
