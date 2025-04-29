class CreateDistricts < ActiveRecord::Migration[8.0]
  def change
    create_table :districts do |t|
      t.string :name, null: false
      t.references :city, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :districts, [:name, :city_id], unique: true
  end
end
