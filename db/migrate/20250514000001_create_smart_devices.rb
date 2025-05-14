class CreateSmartDevices < ActiveRecord::Migration[7.0]
  def change
    create_table :smart_devices do |t|
      t.string :name, null: false
      t.string :device_id, null: false
      t.string :device_type, null: false
      t.text :description
      t.references :building, foreign_key: true
      
      t.timestamps
    end
    add_index :smart_devices, :device_id, unique: true
  end
end
