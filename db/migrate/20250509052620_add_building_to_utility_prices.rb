class AddBuildingToUtilityPrices < ActiveRecord::Migration[8.0]
  def change
    add_reference :utility_prices, :building, null: true, foreign_key: true
  end
end
