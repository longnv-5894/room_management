class UpdateDeviceUsersUniqueIndex < ActiveRecord::Migration[8.0]
  def change
    # Remove the existing unique index
    remove_index :device_users, [ :smart_device_id, :user_id ], unique: true, if_exists: true

    # Add a new unique index that includes unlock_sn
    add_index :device_users, [ :smart_device_id, :user_id, :unlock_sn ], unique: true
  end
end
