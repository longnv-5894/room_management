class AddPaymentFrequenciesToRoomAssignments < ActiveRecord::Migration[8.0]
  def change
    add_column :room_assignments, :room_fee_frequency, :integer, default: 1
    add_column :room_assignments, :utility_fee_frequency, :integer, default: 1
  end
end