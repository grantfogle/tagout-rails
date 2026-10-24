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

ActiveRecord::Schema.define(version: 2026_10_23_000000) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "feedbacks", force: :cascade do |t|
    t.string "email"
    t.text "comment", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "hunt_stats", force: :cascade do |t|
    t.string "hunt_code"
    t.string "state"
    t.string "species"
    t.string "sex"
    t.string "unit"
    t.string "season"
    t.string "hunt_method"
    t.boolean "resident"
    t.boolean "adult"
    t.string "draw_type"
    t.integer "value"
    t.integer "applicants"
    t.integer "success"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["hunt_code", "resident", "adult", "draw_type", "value"], name: "index_hunt_stats_unique_key", unique: true
  end

  create_table "preference_points", force: :cascade do |t|
    t.bigint "profile_id", null: false
    t.string "species", null: false
    t.integer "points", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["profile_id", "species"], name: "index_preference_points_on_profile_id_and_species", unique: true
    t.index ["profile_id"], name: "index_preference_points_on_profile_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "residency_state"
    t.boolean "resident"
    t.string "favorite_species", default: [], null: false, array: true
    t.string "states_of_interest", default: [], null: false, array: true
    t.string "preferred_methods", default: [], null: false, array: true
    t.boolean "notifications_enabled", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_profiles_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "preference_points", "profiles"
  add_foreign_key "profiles", "users"
end
