class AddServiceChargeToUtilityReadings < ActiveRecord::Migration[8.0]
  def change
    add_column :utility_readings, :service_charge, :decimal, precision: 10, scale: 2, default: nil
  end
end
