class AddServiceFeeToBills < ActiveRecord::Migration[8.0]
  def change
    add_column :bills, :service_fee, :decimal, precision: 12, scale: 2, default: 0
  end
end
