class CreateUtilityPrices < ActiveRecord::Migration[8.0]
  def change
    create_table :utility_prices do |t|
      t.decimal :electricity_unit_price, precision: 10, scale: 2, null: false, default: 0
      t.decimal :water_unit_price, precision: 10, scale: 2, null: false, default: 0
      t.decimal :service_charge, precision: 10, scale: 2, null: false, default: 0
      t.date :effective_date, null: false
      t.text :notes

      t.timestamps
    end
    
    add_index :utility_prices, :effective_date
  end
end
