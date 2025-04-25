class AddBuildingToOperatingExpenses < ActiveRecord::Migration[8.0]
  def change
    add_reference :operating_expenses, :building, null: true, foreign_key: true
  end
end
