class CreateBuildings < ActiveRecord::Migration[8.0]
  def change
    create_table :buildings do |t|
      t.string :name
      t.string :address
      t.text :description
      t.references :user, null: false, foreign_key: true
      t.integer :num_floors
      t.integer :year_built
      t.float :total_area
      t.string :status

      t.timestamps
    end
  end
end
