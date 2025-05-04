class CreateContracts < ActiveRecord::Migration[8.0]
  def change
    create_table :contracts do |t|
      t.references :room_assignment, null: false, foreign_key: true
      t.string :contract_number
      t.date :start_date
      t.date :end_date
      t.decimal :rent_amount
      t.decimal :deposit_amount
      t.string :status
      t.text :notes

      t.timestamps
    end
  end
end
