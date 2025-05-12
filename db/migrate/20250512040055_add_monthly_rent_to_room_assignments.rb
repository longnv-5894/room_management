class AddMonthlyRentToRoomAssignments < ActiveRecord::Migration[8.0]
  def change
    add_column :room_assignments, :monthly_rent, :decimal, precision: 12, scale: 2, default: 0
  end
end
