class SmartDevice < ApplicationRecord
  validates :name, presence: true
  validates :device_id, presence: true
  validates :device_type, presence: true

  belongs_to :building, optional: true
  belongs_to :room, optional: true

  has_many :unlock_records, dependent: :destroy
  has_many :device_users, dependent: :destroy

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

    # By default, use local database records
    begin
      start_time = Time.now - days.days
      records = unlock_records.where("time >= ?", start_time).order(time: :desc).limit(50)

      {
        success: true,
        records: records.map { |record|
          {
            time: record.time.getlocal("+07:00").strftime("%Y-%m-%d %H:%M:%S"),
            user: record.user_name,
            user_name: record.user_name,
            method: record.unlock_method,
            success: record.success,
            raw_data: record.raw_data
          }
        },
        count: records.size,
        has_more: false,
        page_no: 1,
        page_size: 50,
        from_database: true
      }
    rescue => e
      { error: e.message, records: [] }
    end
  end

  # Get unlock records directly from Tuya API for sync operations
  # options parameter can contain page_no, page_size, start_time, end_time
  def get_unlock_records_from_api(options = {})
    return { error: "Thiết bị không phải là khóa cửa" } unless smart_lock?

    begin
      lock_service = TuyaSmartLockService.new

      # Set default options if not provided
      default_options = {
        page_no: options[:page_no] || 1,
        page_size: options[:page_size] || 20
      }

      # If start_time is not provided, set default based on context
      if !options[:start_time]
        # Default to 30 days ago
        default_options[:start_time] = (Time.now - 30.days).to_i * 1000
        default_options[:end_time] = Time.now.to_i * 1000
      end

      # Merge user provided options with defaults
      request_options = default_options.merge(options.compact)

      # Log the time range being queried
      if request_options[:start_time] && request_options[:end_time]
        start_time_str = Time.at(request_options[:start_time]/1000).to_s
        end_time_str = Time.at(request_options[:end_time]/1000).to_s
        Rails.logger.info("Fetching records from #{start_time_str} to #{end_time_str}, page #{request_options[:page_no]}")
      end

      # Make the API call
      lock_service.get_unlock_records(device_id, request_options)
    rescue => e
      Rails.logger.error("Error fetching unlock records: #{e.message}")
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

    # By default, get users from database
    begin
      offset = (page - 1) * page_size
      users = device_users.limit(page_size).offset(offset)
      total_count = device_users.count

      {
        users: users.map { |user|
          {
            id: user.user_id,
            name: user.name,
            avatar_url: user.avatar_url,
            role: user.role,
            status: user.status || "active",
            create_time: user.created_at&.strftime("%Y-%m-%d %H:%M:%S"),
            update_time: user.updated_at&.strftime("%Y-%m-%d %H:%M:%S"),
            raw_data: user.raw_data
          }
        },
        count: total_count,
        has_more: (offset + page_size) < total_count,
        page_no: page,
        page_size: page_size,
        from_database: true
      }
    rescue => e
      { error: e.message, users: [] }
    end
  end

  # Get device users directly from Tuya API for sync operations
  def get_lock_users_from_api(page = 1, page_size = 20, last_update_time = nil)
    return { error: "Thiết bị không phải là khóa cửa", users: [] } unless smart_lock?

    begin
      lock_service = TuyaSmartLockService.new

      # If there's a last_update_time parameter, include it in the API request
      options = {
        page_no: page,
        page_size: page_size
      }

      # If we have a last update time, add it to the request to only get users modified since then
      if last_update_time.present?
        # Convert to milliseconds timestamp for the API
        if last_update_time.is_a?(Time)
          options[:last_update_time] = last_update_time.to_i * 1000
        else
          options[:last_update_time] = last_update_time.to_i
        end
        Rails.logger.info("Fetching users updated since: #{Time.at(options[:last_update_time]/1000)}")
      end

      api_response = lock_service.get_lock_users(device_id, options)

      # Nếu có lỗi, trả về luôn
      return api_response if api_response[:error].present?

      # Xử lý dữ liệu trả về để đảm bảo mỗi người dùng có thông tin về các unlock_methods
      if api_response[:users].present?
        modified_users = api_response[:users].map do |user|
          # Đảm bảo raw_data chứa thông tin original và unlock_methods (nếu có)
          if user[:raw_data].blank?
            user[:raw_data] = user.except(:raw_data)
          end

          # Thêm thông tin về các phương thức mở khóa
          if user[:unlock_sn].present? || user[:dp_code].present?
            # Nếu thông tin về phương thức mở khóa đã được gán trực tiếp vào user
            user[:raw_data]["unlock_methods"] ||= []
            user[:raw_data]["unlock_methods"] << {
              "unlock_sn" => user[:unlock_sn],
              "dp_code" => user[:dp_code],
              "unlock_name" => user[:unlock_name],
              "user_type" => user[:user_type]
            }.compact
          end

          user
        end

        api_response[:users] = modified_users
      end

      api_response
    rescue => e
      Rails.logger.error("Error fetching device users: #{e.message}")
      { error: e.message, users: [] }
    end
  end

  # Đồng bộ dữ liệu từ Tuya API cho khóa cửa thông minh
  def sync_data_from_tuya
    return { error: "Thiết bị không phải là khóa cửa" } unless smart_lock?

    results = {}

    # Lấy dữ liệu từ API Tuya và đồng bộ vào cơ sở dữ liệu
    # Đồng bộ lịch sử mở khóa
    unlock_results = UnlockRecord.sync_from_tuya(self)
    results[:unlock_records] = unlock_results

    # Đồng bộ người dùng
    users_results = DeviceUser.sync_from_tuya(self)
    results[:device_users] = users_results

    results
  end

  # Lấy lịch sử mở khóa từ database
  def local_unlock_records(limit = 50)
    unlock_records.recent.limit(limit)
  end

  # Lấy danh sách người dùng từ database
  def local_device_users
    device_users
  end

  def self.device_types
    [ "fingerprint_lock", "smart_lock", "camera", "light", "switch", "other" ]
  end
end
