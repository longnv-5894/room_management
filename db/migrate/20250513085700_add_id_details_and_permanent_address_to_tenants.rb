class AddIdDetailsAndPermanentAddressToTenants < ActiveRecord::Migration[8.0]
  def change
    add_column :tenants, :id_issue_date, :date
    add_column :tenants, :id_issue_place, :string
    add_column :tenants, :permanent_address, :text
  end
end
