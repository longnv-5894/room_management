class CreateUtilityReadings < ActiveRecord::Migration[8.0]
  def change
    create_table :utility_readings do |t|
      t.references :room, null: false, foreign_key: true
      t.date :reading_date, null: false
      t.decimal :electricity_reading, precision: 10, scale: 2, default: 0
      t.decimal :water_reading, precision: 10, scale: 2, default: 0
      t.decimal :electricity_unit_price, precision: 8, scale: 2, default: 0
      t.decimal :water_unit_price, precision: 8, scale: 2, default: 0

      t.timestamps
    end
    
    add_index :utility_readings, [:room_id, :reading_date]
  end
end
