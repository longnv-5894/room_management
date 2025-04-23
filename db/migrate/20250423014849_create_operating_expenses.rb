class CreateOperatingExpenses < ActiveRecord::Migration[8.0]
  def change
    create_table :operating_expenses do |t|
      t.string :category
      t.string :description
      t.decimal :amount
      t.date :expense_date

      t.timestamps
    end
  end
end
