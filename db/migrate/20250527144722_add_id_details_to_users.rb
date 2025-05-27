class AddIdDetailsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :id_issue_date, :date
    add_column :users, :id_issue_place, :string
  end
end
