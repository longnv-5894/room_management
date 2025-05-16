class CreateDeviceUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :device_users do |t|
      t.references :smart_device, null: false, foreign_key: true
      t.references :tenant, null: true, foreign_key: true  # Có thể chưa liên kết với tenant
      t.string :user_id, null: false                       # ID từ Tuya API
      t.string :name
      t.string :status
      t.string :avatar_url
      t.datetime :last_active_at
      t.json :raw_data

      t.timestamps
    end

    add_index :device_users, [ :smart_device_id, :user_id ], unique: true
    add_index :device_users, :user_id
  end
end
