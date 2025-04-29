class CreateWards < ActiveRecord::Migration[8.0]
  def change
    create_table :wards do |t|
      t.string :name, null: false
      t.references :district, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :wards, [:name, :district_id], unique: true
  end
end
