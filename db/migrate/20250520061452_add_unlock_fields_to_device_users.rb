class AddUnlockFieldsToDeviceUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :device_users, :unlock_sn, :integer
    add_column :device_users, :dp_code, :string
    add_column :device_users, :unlock_name, :string
    add_column :device_users, :user_type, :integer
  end
end
