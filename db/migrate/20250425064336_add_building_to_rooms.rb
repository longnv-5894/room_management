class AddBuildingToRooms < ActiveRecord::Migration[8.0]
  def change
    add_reference :rooms, :building, null: true, foreign_key: true
  end
end
