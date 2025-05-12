class RemoveMonthlyRentFromRooms < ActiveRecord::Migration[8.0]
  def change
    remove_column :rooms, :monthly_rent, :decimal
  end
end
