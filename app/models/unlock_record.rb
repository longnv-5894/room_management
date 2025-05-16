class UnlockRecord < ApplicationRecord
  belongs_to :smart_device
  belongs_to :device_user, foreign_key: 'user_id', primary_key: 'user_id', optional: true

  validates :time, presence: true
  validates :record_id, uniqueness: true, allow_nil: true

  scope :recent, -> { order(time: :desc) }
  # Scope to get recent records

  # Class method to sync records from Tuya API
  def self.sync_from_tuya(smart_device, days = 7)
    return unless smart_device.smart_lock?

    # Lấy dữ liệu từ Tuya API sử dụng phương thức mới
    api_response = smart_device.get_unlock_records_from_api(days)

    return { error: api_response[:error] } if api_response[:error].present?

    records_synced = 0
    records_skipped = 0

    if api_response[:records].present?
      api_response[:records].each do |record|
        # Tạo record_id bằng cách kết hợp device_id và thời gian (nếu không có id)
        unlock_time = if record[:time].is_a?(String)
          Time.parse(record[:time]) rescue Time.now
        else
                      Time.at(record[:time] / 1000) rescue Time.now
        end

        # Kiểm tra xem bản ghi đã tồn tại chưa
        existing = UnlockRecord.find_by(smart_device: smart_device, time: unlock_time)

        if existing.nil?
          # Tạo bản ghi mới nếu chưa tồn tại


          UnlockRecord.create!(
            smart_device: smart_device,
            time: unlock_time,
            user_id: record[:user],
            user_name: record[:unlock_name],
            unlock_method: record[:method],
            success: record[:success] || true,
            raw_data: record[:raw_data] || record
          )
          records_synced += 1
        else
          records_skipped += 1
        end
      end
    end

    { synced: records_synced, skipped: records_skipped, total: api_response[:records].size }
  end
end
