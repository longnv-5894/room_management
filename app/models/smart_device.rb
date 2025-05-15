class SmartDevice < ApplicationRecord
  validates :name, presence: true
  validates :device_id, presence: true
  validates :device_type, presence: true

  belongs_to :building, optional: true
  belongs_to :room, optional: true

  # Check if device is currently online/active
  def online?
    begin
      # If there's a cached status, use it
      return @device_status[:online] if defined?(@device_status) && @device_status.is_a?(Hash) && !@device_status[:online].nil?

      # Otherwise fetch fresh status
      service = TuyaCloudService.new
      response = service.get_device_info(device_id)

      # Cache the response for future use
      @device_status = response

      # Return online status if available, otherwise assume offline
      response&.dig(:online) == true
    rescue => e
      # If any error occurs, default to offline
      Rails.logger.error("Error checking device online status: #{e.message}")
      false
    end
  end

  # Device online status for quick access without API call
  def device_status
    return @device_status[:state] if defined?(@device_status) && @device_status.is_a?(Hash) && !@device_status[:state].nil?

    begin
      response = fetch_device_info
      return "unknown" if response.blank? || response[:error].present?

      if smart_lock?
        response[:lock_state] == "locked" ? "locked" : "unlocked"
      elsif device_type == "smart_switch"
        response[:state] == true ? "on" : "off"
      else
        "unknown"
      end
    rescue => e
      Rails.logger.error("Error getting device status: #{e.message}")
      "unknown"
    end
  end

  # Accessor for device data (temperature, humidity, etc.)
  def device_data
    return @device_status[:data] if defined?(@device_status) && @device_status.is_a?(Hash) && !@device_status[:data].nil?

    begin
      response = fetch_device_info
      return {} if response.blank? || response[:error].present?

      response[:data] || {}
    rescue => e
      Rails.logger.error("Error getting device data: #{e.message}")
      {}
    end
  end

  def fetch_device_info
    begin
      service = TuyaCloudService.new
      service.get_device_info(device_id)
    rescue => e
      { error: e.message }
    end
  end

  def fetch_device_functions
    begin
      service = TuyaCloudService.new
      service.get_device_functions(device_id)
    rescue => e
      { error: e.message }
    end
  end

  def fetch_device_logs(days = 7)
    begin
      service = TuyaCloudService.new
      end_time = Time.now
      start_time = end_time - days.days

      # Pass parameters as an options hash to match the updated service method
      service.get_device_logs(device_id, {
        start_time: start_time,
        end_time: end_time,
        type: "1",  # Default to common event types
        size: 50      # Get more logs by default
      })
    rescue => e
      { error: e.message }
    end
  end

  # Kiểm tra xem thiết bị có phải là khóa cửa không
  def smart_lock?
    device_type == "smart_lock" || device_type == "fingerprint_lock"
  end

  # Lấy trạng thái khóa
  def get_lock_status
    return { error: "Thiết bị không phải là khóa cửa" } unless smart_lock?

    begin
      lock_service = TuyaSmartLockService.new
      lock_service.get_lock_status(device_id)
    rescue => e
      { error: e.message }
    end
  end

  # Mở khóa
  def unlock
    return { error: "Thiết bị không phải là khóa cửa" } unless smart_lock?

    begin
      lock_service = TuyaSmartLockService.new
      lock_service.unlock_door(device_id)
    rescue => e
      { error: e.message }
    end
  end

  # Khóa cửa
  def lock
    return { error: "Thiết bị không phải là khóa cửa" } unless smart_lock?

    begin
      lock_service = TuyaSmartLockService.new
      lock_service.lock_door(device_id)
    rescue => e
      { error: e.message }
    end
  end

  # Kiểm tra pin
  def get_battery_level
    return { error: "Thiết bị không phải là khóa cửa" } unless smart_lock?

    begin
      lock_service = TuyaSmartLockService.new
      lock_service.get_battery_level(device_id)
    rescue => e
      { error: e.message }
    end
  end

  # Lấy lịch sử mở khóa
  def get_unlock_records(days = 7)
    return { error: "Thiết bị không phải là khóa cửa" } unless smart_lock?

    begin
      lock_service = TuyaSmartLockService.new
      end_time = Time.now.to_i * 1000
      start_time = (Time.now - days.days).to_i * 1000

      lock_service.get_unlock_records(device_id, start_time, end_time)
    rescue => e
      { error: e.message, records: [] }
    end
  end

  # Lấy danh sách mật khẩu
  def get_password_list
    return { error: "Thiết bị không phải là khóa cửa" } unless smart_lock?

    begin
      lock_service = TuyaSmartLockService.new
      lock_service.get_password_list(device_id)
    rescue => e
      { error: e.message }
    end
  end

  # Thêm mật khẩu mới
  def add_password(password, name, options = {})
    return { error: "Thiết bị không phải là khóa cửa" } unless smart_lock?

    begin
      lock_service = TuyaSmartLockService.new

      password_data = {
        password: password,
        name: name
      }

      # Thêm các thông số tùy chọn nếu được cung cấp
      password_data[:effective_time] = options[:start_time] if options[:start_time]
      password_data[:invalid_time] = options[:end_time] if options[:end_time]
      password_data[:type] = options[:type] if options[:type]

      lock_service.add_password(device_id, password_data)
    rescue => e
      { error: e.message, success: false }
    end
  end

  # Xóa mật khẩu
  def delete_password(password_id)
    return { error: "Thiết bị không phải là khóa cửa" } unless smart_lock?

    begin
      lock_service = TuyaSmartLockService.new
      lock_service.delete_password(device_id, password_id)
    rescue => e
      { error: e.message, success: false }
    end
  end

  # Lấy danh sách người dùng của khóa
  def get_lock_users(page = 1, page_size = 20)
    return { error: "Thiết bị không phải là khóa cửa", users: [] } unless smart_lock?

    begin
      lock_service = TuyaSmartLockService.new
      lock_service.get_lock_users(device_id, page, page_size)
    rescue => e
      { error: e.message, users: [] }
    end
  end

  def self.device_types
    [ "fingerprint_lock", "smart_lock", "camera", "light", "switch", "other" ]
  end
end
