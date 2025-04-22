class CreateRoomAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :room_assignments do |t|
      t.references :room, null: false, foreign_key: true
      t.references :tenant, null: false, foreign_key: true
      t.date :start_date, null: false
      t.date :end_date
      t.decimal :deposit_amount, precision: 10, scale: 2
      t.boolean :active, default: true

      t.timestamps
    end
    
    add_index :room_assignments, [:room_id, :tenant_id, :active], unique: true, 
      where: "active = true", name: "unique_active_room_assignments"
  end
end
