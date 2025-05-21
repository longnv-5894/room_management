class DeviceUser < ApplicationRecord
  belongs_to :smart_device
  belongs_to :tenant, optional: true
  has_many :unlock_records, foreign_key: "user_id", primary_key: "user_id"

  validates :user_id, presence: true
  # Update validation to make user_id and unlock_sn combination unique
  validates :user_id, uniqueness: { scope: [ :smart_device_id, :unlock_sn ] }

  # Sync device users from Tuya API
  def self.sync_from_tuya(smart_device)
    return unless smart_device.smart_lock?

    # Get data from Tuya API using the new method specifically for API calls
    api_response = smart_device.get_lock_users_from_api()

    return { error: api_response[:error] } if api_response[:error].present?

    users_synced = 0
    users_updated = 0

    if api_response[:users].present?
      api_response[:users].each do |user|
        next unless user[:id].present?

        # Kiểm tra nếu người dùng có nhiều phương thức mở khóa
        if user[:raw_data].present? && user[:raw_data]["unlock_methods"].present? && user[:raw_data]["unlock_methods"].is_a?(Array)
          # Xử lý mỗi phương thức mở khóa như một bản ghi DeviceUser riêng biệt
          user[:raw_data]["unlock_methods"].each do |method|
            # Look for existing device user with this specific user_id and unlock_sn combination
            device_user = DeviceUser.find_or_initialize_by(
              smart_device: smart_device,
              user_id: user[:id],
              unlock_sn: method["unlock_sn"]
            )

            # Update attributes
            is_new_record = device_user.new_record?
            device_user.name = user[:name]
            device_user.status = user[:status] || "active"
            device_user.avatar_url = user[:avatar_url]

            # Lưu các thông tin về phương thức mở khóa
            device_user.dp_code = method["dp_code"]
            device_user.unlock_name = method["unlock_name"]
            device_user.user_type = method["user_type"]

            # Lưu thông tin gốc của người dùng vào raw_data
            device_user.raw_data = {
              user: user[:raw_data],
              method: method
            }

            device_user.last_active_at = Time.now

            if device_user.save
              if is_new_record
                users_synced += 1
              else
                users_updated += 1
              end
            end
          end
        else
          # Trường hợp không có unlock_methods, xử lý như thông thường
          device_user = DeviceUser.find_or_initialize_by(
            smart_device: smart_device,
            user_id: user[:id]
          )

          # Update attributes
          is_new_record = device_user.new_record?
          device_user.name = user[:name]
          device_user.status = user[:status] || "active"
          device_user.avatar_url = user[:avatar_url]
          device_user.raw_data = user[:raw_data] || user
          device_user.last_active_at = Time.now

          if device_user.save
            if is_new_record
              users_synced += 1
            else
              users_updated += 1
            end
          end
        end
      end
    end

    { synced: users_synced, updated: users_updated, total: api_response[:users].size }
  end

  # Associate a device user with a tenant
  def associate_with_tenant(tenant)
    update(tenant: tenant)
  end

  # Remove tenant association
  def remove_tenant_association
    update(tenant: nil)
  end
end
