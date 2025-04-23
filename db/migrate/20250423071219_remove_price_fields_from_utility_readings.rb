class RemovePriceFieldsFromUtilityReadings < ActiveRecord::Migration[8.0]
  def change
    remove_column :utility_readings, :electricity_unit_price, :decimal
    remove_column :utility_readings, :water_unit_price, :decimal
    remove_column :utility_readings, :service_charge, :decimal
  end
end
