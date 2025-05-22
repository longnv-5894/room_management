class UnlockRecord < ApplicationRecord
  belongs_to :smart_device
  belongs_to :device_user, foreign_key: "user_id", primary_key: "user_id", optional: true

  validates :time, presence: true
  # validates :record_id, uniqueness: true, allow_nil: true

  scope :recent, -> { order(time: :desc) }
  # Scope to get recent records

  # Class method to sync records from Tuya API
  def self.sync_from_tuya(smart_device, days = 7)
    return unless smart_device.smart_lock?

    # First try to fetch newer records
    Rails.logger.info("Attempting to sync newer records first")
    api_response = smart_device.get_unlock_records_from_api(days, :newer)
    
    # If there was an error or no newer records, try older records
    if api_response[:error].present? || (api_response[:records].blank? || api_response[:records].empty?)
      Rails.logger.info("No newer records found or error occurred, trying older records")
      api_response = smart_device.get_unlock_records_from_api(days, :older)
    end

    return { error: api_response[:error] } if api_response[:error].present?
    
    # If we still don't have any records after trying both directions,
    # and there are no existing records, try the default range
    if (api_response[:records].blank? || api_response[:records].empty?) && 
       !smart_device.unlock_records.exists?
      Rails.logger.info("No records found in both directions and no existing records, trying default range")
      api_response = smart_device.get_unlock_records_from_api(days)
    end

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
