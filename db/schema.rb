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

ActiveRecord::Schema[8.0].define(version: 2025_04_22_043835) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "bills", force: :cascade do |t|
    t.bigint "room_assignment_id", null: false
    t.date "billing_date", null: false
    t.date "due_date", null: false
    t.decimal "room_fee", precision: 10, scale: 2, default: "0.0"
    t.decimal "electricity_fee", precision: 10, scale: 2, default: "0.0"
    t.decimal "water_fee", precision: 10, scale: 2, default: "0.0"
    t.decimal "other_fees", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_amount", precision: 10, scale: 2, default: "0.0"
    t.string "status", default: "unpaid"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["room_assignment_id", "billing_date"], name: "index_bills_on_room_assignment_id_and_billing_date", unique: true
    t.index ["room_assignment_id"], name: "index_bills_on_room_assignment_id"
  end

  create_table "room_assignments", force: :cascade do |t|
    t.bigint "room_id", null: false
    t.bigint "tenant_id", null: false
    t.date "start_date", null: false
    t.date "end_date"
    t.decimal "deposit_amount", precision: 10, scale: 2
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["room_id", "tenant_id", "active"], name: "unique_active_room_assignments", unique: true, where: "(active = true)"
    t.index ["room_id"], name: "index_room_assignments_on_room_id"
    t.index ["tenant_id"], name: "index_room_assignments_on_tenant_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.string "number", null: false
    t.integer "floor"
    t.decimal "area", precision: 8, scale: 2
    t.decimal "monthly_rent", precision: 10, scale: 2, null: false
    t.string "status", default: "available"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["number"], name: "index_rooms_on_number", unique: true
  end

  create_table "tenants", force: :cascade do |t|
    t.string "name", null: false
    t.string "phone"
    t.string "email"
    t.string "id_number", null: false
    t.date "move_in_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_tenants_on_email"
    t.index ["id_number"], name: "index_tenants_on_id_number", unique: true
    t.index ["phone"], name: "index_tenants_on_phone"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email"
  end

  create_table "utility_readings", force: :cascade do |t|
    t.bigint "room_id", null: false
    t.date "reading_date", null: false
    t.decimal "electricity_reading", precision: 10, scale: 2, default: "0.0"
    t.decimal "water_reading", precision: 10, scale: 2, default: "0.0"
    t.decimal "electricity_unit_price", precision: 8, scale: 2, default: "0.0"
    t.decimal "water_unit_price", precision: 8, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["room_id", "reading_date"], name: "index_utility_readings_on_room_id_and_reading_date"
    t.index ["room_id"], name: "index_utility_readings_on_room_id"
  end

  add_foreign_key "bills", "room_assignments"
  add_foreign_key "room_assignments", "rooms"
  add_foreign_key "room_assignments", "tenants"
  add_foreign_key "utility_readings", "rooms"
end
