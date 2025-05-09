class AddPreviousDebtAndOverpaymentToBills < ActiveRecord::Migration[8.0]
  def change
    add_column :bills, :previous_debt, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :bills, :overpayment, :decimal, precision: 10, scale: 2, default: 0.0
  end
end
