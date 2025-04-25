class UpdateRoomNumberUniquenessConstraint < ActiveRecord::Migration[8.0]
  def change
    # Remove existing simple index that enforces global uniqueness
    remove_index :rooms, :number if index_exists?(:rooms, :number)
    
    # Add composite index that enforces uniqueness only within a building
    add_index :rooms, [:building_id, :number], unique: true
  end
end
