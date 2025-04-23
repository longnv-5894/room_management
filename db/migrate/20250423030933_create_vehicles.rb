class CreateVehicles < ActiveRecord::Migration[8.0]
  def change
    create_table :vehicles do |t|
      t.string :license_plate
      t.string :vehicle_type
      t.string :brand
      t.string :model
      t.string :color
      t.references :tenant, null: false, foreign_key: true
      t.text :notes

      t.timestamps
    end
  end
end
