class AddDetailsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :name, :string
    add_column :users, :phone, :string
    add_column :users, :address, :text
    add_column :users, :gender, :string
    add_column :users, :date_of_birth, :date
    add_column :users, :id_number, :string
  end
end
