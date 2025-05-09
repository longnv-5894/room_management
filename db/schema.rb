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

ActiveRecord::Schema[8.0].define(version: 2025_05_09_052620) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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
    t.decimal "service_fee", precision: 12, scale: 2, default: "0.0"
    t.decimal "previous_debt", precision: 10, scale: 2, default: "0.0"
    t.decimal "overpayment", precision: 10, scale: 2, default: "0.0"
    t.index ["room_assignment_id", "billing_date"], name: "index_bills_on_room_assignment_id_and_billing_date", unique: true
    t.index ["room_assignment_id"], name: "index_bills_on_room_assignment_id"
  end

  create_table "buildings", force: :cascade do |t|
    t.string "name"
    t.string "address"
    t.text "description"
    t.bigint "user_id", null: false
    t.integer "num_floors"
    t.integer "year_built"
    t.float "total_area"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "country_id"
    t.bigint "city_id"
    t.bigint "district_id"
    t.bigint "ward_id"
    t.string "street_address"
    t.index ["city_id"], name: "index_buildings_on_city_id"
    t.index ["country_id"], name: "index_buildings_on_country_id"
    t.index ["district_id"], name: "index_buildings_on_district_id"
    t.index ["user_id"], name: "index_buildings_on_user_id"
    t.index ["ward_id"], name: "index_buildings_on_ward_id"
  end

  create_table "cities", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "country_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country_id"], name: "index_cities_on_country_id"
    t.index ["name", "country_id"], name: "index_cities_on_name_and_country_id", unique: true
  end

  create_table "contracts", force: :cascade do |t|
    t.bigint "room_assignment_id", null: false
    t.string "contract_number"
    t.date "start_date"
    t.date "end_date"
    t.decimal "rent_amount"
    t.decimal "deposit_amount"
    t.string "status"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "payment_due_day"
    t.index ["room_assignment_id"], name: "index_contracts_on_room_assignment_id"
  end

  create_table "countries", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_countries_on_code", unique: true
  end

  create_table "districts", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "city_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["city_id"], name: "index_districts_on_city_id"
    t.index ["name", "city_id"], name: "index_districts_on_name_and_city_id", unique: true
  end

  create_table "operating_expenses", force: :cascade do |t|
    t.string "category"
    t.string "description"
    t.decimal "amount"
    t.date "expense_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "building_id"
    t.index ["building_id"], name: "index_operating_expenses_on_building_id"
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
    t.text "notes"
    t.boolean "is_representative_tenant", default: false
    t.integer "room_fee_frequency", default: 1
    t.integer "utility_fee_frequency", default: 1
    t.index ["room_id", "tenant_id", "active"], name: "unique_active_room_assignments", unique: true, where: "(active = true)"
    t.index ["room_id"], name: "index_room_assignments_on_room_id"
    t.index ["room_id"], name: "index_room_assignments_on_room_representative", unique: true, where: "((active = true) AND (is_representative_tenant = true))"
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
    t.bigint "building_id"
    t.index ["building_id", "number"], name: "index_rooms_on_building_id_and_number", unique: true
    t.index ["building_id"], name: "index_rooms_on_building_id"
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
    t.string "name"
    t.string "phone"
    t.text "address"
    t.string "gender"
    t.date "date_of_birth"
    t.string "id_number"
    t.index ["email"], name: "index_users_on_email"
  end

  create_table "utility_prices", force: :cascade do |t|
    t.decimal "electricity_unit_price", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "water_unit_price", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "service_charge", precision: 10, scale: 2, default: "0.0", null: false
    t.date "effective_date", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "building_id"
    t.index ["building_id"], name: "index_utility_prices_on_building_id"
    t.index ["effective_date"], name: "index_utility_prices_on_effective_date"
  end

  create_table "utility_readings", force: :cascade do |t|
    t.bigint "room_id", null: false
    t.date "reading_date", null: false
    t.decimal "electricity_reading", precision: 10, scale: 2, default: "0.0"
    t.decimal "water_reading", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["room_id", "reading_date"], name: "index_utility_readings_on_room_id_and_reading_date"
    t.index ["room_id"], name: "index_utility_readings_on_room_id"
  end

  create_table "vehicles", force: :cascade do |t|
    t.string "license_plate"
    t.string "vehicle_type"
    t.string "brand"
    t.string "model"
    t.string "color"
    t.bigint "tenant_id", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_vehicles_on_tenant_id"
  end

  create_table "wards", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "district_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["district_id"], name: "index_wards_on_district_id"
    t.index ["name", "district_id"], name: "index_wards_on_name_and_district_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bills", "room_assignments"
  add_foreign_key "buildings", "cities"
  add_foreign_key "buildings", "countries"
  add_foreign_key "buildings", "districts"
  add_foreign_key "buildings", "users"
  add_foreign_key "buildings", "wards"
  add_foreign_key "cities", "countries"
  add_foreign_key "contracts", "room_assignments"
  add_foreign_key "districts", "cities"
  add_foreign_key "operating_expenses", "buildings"
  add_foreign_key "room_assignments", "rooms"
  add_foreign_key "room_assignments", "tenants"
  add_foreign_key "rooms", "buildings"
  add_foreign_key "utility_prices", "buildings"
  add_foreign_key "utility_readings", "rooms"
  add_foreign_key "vehicles", "tenants"
  add_foreign_key "wards", "districts"
end
