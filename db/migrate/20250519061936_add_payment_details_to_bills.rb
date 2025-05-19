class AddPaymentDetailsToBills < ActiveRecord::Migration[8.0]
  def change
    add_column :bills, :paid_amount, :decimal, precision: 10, scale: 2, default: 0
    add_column :bills, :remaining_amount, :decimal, precision: 10, scale: 2, default: 0
    add_column :bills, :payment_history, :text

    # Đảm bảo các trường mới thêm có giá trị đúng cho các hóa đơn hiện có
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE bills SET#{' '}
            paid_amount = CASE WHEN status = 'paid' THEN total_amount ELSE 0 END,
            remaining_amount = CASE WHEN status = 'paid' THEN 0 ELSE total_amount END
        SQL
      end
    end
  end
end
