class CreateBills < ActiveRecord::Migration[8.0]
  def change
    create_table :bills do |t|
      t.references :room_assignment, null: false, foreign_key: true
      t.date :billing_date, null: false
      t.date :due_date, null: false
      t.decimal :room_fee, precision: 10, scale: 2, default: 0
      t.decimal :electricity_fee, precision: 10, scale: 2, default: 0
      t.decimal :water_fee, precision: 10, scale: 2, default: 0
      t.decimal :other_fees, precision: 10, scale: 2, default: 0
      t.decimal :total_amount, precision: 10, scale: 2, default: 0
      t.string :status, default: 'unpaid'
      t.text :notes

      t.timestamps
    end
    
    add_index :bills, [:room_assignment_id, :billing_date], unique: true
  end
end
