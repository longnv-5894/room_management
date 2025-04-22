class CreateTenants < ActiveRecord::Migration[8.0]
  def change
    create_table :tenants do |t|
      t.string :name, null: false
      t.string :phone
      t.string :email
      t.string :id_number, null: false
      t.date :move_in_date

      t.timestamps
    end
    
    add_index :tenants, :id_number, unique: true
    add_index :tenants, :phone
    add_index :tenants, :email
  end
end
