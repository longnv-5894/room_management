class CreateRooms < ActiveRecord::Migration[8.0]
  def change
    create_table :rooms do |t|
      t.string :number, null: false
      t.integer :floor
      t.decimal :area, precision: 8, scale: 2
      t.decimal :monthly_rent, precision: 10, scale: 2, null: false
      t.string :status, default: 'available'

      t.timestamps
    end
    
    add_index :rooms, :number, unique: true
  end
end
