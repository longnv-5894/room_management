class AddPaymentDueDayToContracts < ActiveRecord::Migration[8.0]
  def change
    add_column :contracts, :payment_due_day, :integer
  end
end
