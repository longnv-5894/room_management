class AddNotesToRoomAssignments < ActiveRecord::Migration[8.0]
  def change
    add_column :room_assignments, :notes, :text
  end
end
