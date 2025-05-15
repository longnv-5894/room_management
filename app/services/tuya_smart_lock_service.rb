class TuyaSmartLockService
  attr_reader :tuya_service

  # Các mã lệnh cho khóa cửa thông minh
  LOCK_CODES = {
    open_door: "unlock", # Mở cửa
    lock_door: "lock", # Khóa cửa
    get_lock_status: "lock_status", # Kiểm tra trạng thái khóa
    get_battery: "battery_percentage", # Kiểm tra pin
    get_password_records: "password_records", # Lấy danh sách mật khẩu
    add_password: "add_password", # Thêm mật khẩu
    delete_password: "delete_password", # Xóa mật khẩu
    update_password: "update_password", # Cập nhật mật khẩu
    get_open_records: "open_records" # Lấy lịch sử mở cửa
  }

  # Các endpoints chuyên biệt cho khóa cửa
  DOOR_LOCK_ENDPOINTS = {
    unlock: "/v1.0/devices/%{device_id}/door-lock/unlock",
    lock: "/v1.0/devices/%{device_id}/door-lock/lock",
    state: "/v1.0/devices/%{device_id}/door-lock/state",
    passwords: "/v1.0/devices/%{device_id}/door-lock/passwords",
    password: "/v1.0/devices/%{device_id}/door-lock/passwords/%{password_id}",
    open_logs: "/v1.0/devices/%{device_id}/door-lock/open-logs",
    users: "/v1.0/devices/%{device_id}/users" # Thêm endpoint mới để lấy danh sách người dùng
  }

  # Khởi tạo service
  def initialize
    @tuya_service = TuyaCloudService.new
  end

  # Mở khóa cửa sử dụng API chuyên biệt
  def unlock_door(device_id)
    path = DOOR_LOCK_ENDPOINTS[:unlock] % { device_id: device_id }
    door_lock_api_call("POST", path)
  end

  # Khóa cửa sử dụng API chuyên biệt
  def lock_door(device_id)
    path = DOOR_LOCK_ENDPOINTS[:lock] % { device_id: device_id }
    door_lock_api_call("POST", path)
  end

  # Lấy trạng thái khóa sử dụng API chuyên biệt
  def get_lock_status(device_id)
    path = DOOR_LOCK_ENDPOINTS[:state] % { device_id: device_id }
    result = door_lock_api_call("GET", path)

    if result && result[:success] && result[:data]
      data = result[:data]
      {
        status: data["locked"] || false,
        locked: data["locked"] || false,
        battery_level: data["battery_level"],
        online: data["online"] || false,
        timestamp: Time.now,
        raw_data: data
      }
    else
      # Fallback thử lấy từ device info nếu API chuyên biệt không hoạt động
      device_info = @tuya_service.get_device_info(device_id)

      if device_info && device_info["status"]
        status = device_info["status"].find { |s| s["code"] == LOCK_CODES[:get_lock_status] }

        if status
          {
            status: status["value"],
            locked: status["value"],
            timestamp: Time.now,
            via: "device_info"
          }
        else
          { error: "Không tìm thấy thông tin trạng thái khóa" }
        end
      else
        { error: "Không thể lấy thông tin thiết bị" }
      end
    end
  end

  # Kiểm tra pin - sử dụng API state hoặc thông tin thiết bị
  def get_battery_level(device_id)
    # Đầu tiên thử dùng API state
    path = DOOR_LOCK_ENDPOINTS[:state] % { device_id: device_id }
    result = door_lock_api_call("GET", path)

    if result && result[:success] && result[:data] && result[:data]["battery_level"]
      {
        level: result[:data]["battery_level"],
        percentage: result[:data]["battery_level"],
        timestamp: Time.now
      }
    else
      # Fallback: lấy từ device info
      device_info = @tuya_service.get_device_info(device_id)

      if device_info && device_info["status"]
        battery = device_info["status"].find { |s| s["code"] == LOCK_CODES[:get_battery] }

        if battery
          {
            level: battery["value"],
            percentage: battery["value"],
            timestamp: Time.now
          }
        else
          { error: "Không tìm thấy thông tin pin" }
        end
      else
        { error: "Không thể lấy thông tin thiết bị" }
      end
    end
  end

  # Lấy lịch sử mở khóa sử dụng API chuyên biệt
  def get_unlock_records(device_id, start_time = nil, end_time = nil, size = 20)
    begin
      # Đảm bảo đã có token xác thực
      @tuya_service.get_access_token unless @tuya_service.instance_variable_get(:@access_token)

      # Chuẩn bị các tham số
      timestamp = @tuya_service.generate_timestamp

      # Sử dụng endpoint đúng cho khóa cửa thông minh
      path = DOOR_LOCK_ENDPOINTS[:open_logs] % { device_id: device_id }

      # Tham số truy vấn
      query_params = {
        start_time: start_time || (Time.now - 7.days).to_i * 1000,
        end_time: end_time || Time.now.to_i * 1000,
        size: size
      }

      # Sắp xếp tham số để tạo query string
      query_params = query_params.sort.to_h
      query = URI.encode_www_form(query_params)

      # Tạo URI đầy đủ
      uri = URI("#{@tuya_service.instance_variable_get(:@api_endpoint)}#{path}?#{query}")

      # Tạo chuỗi để ký
      string_to_sign = @tuya_service.create_string_to_sign("GET", path, query)

      # Tạo chữ ký
      sign = @tuya_service.generate_sign(
        string_to_sign,
        timestamp,
        @tuya_service.instance_variable_get(:@access_token)
      )

      # Chuẩn bị headers
      headers = {
        "client_id" => @tuya_service.instance_variable_get(:@client_id),
        "sign" => sign,
        "t" => timestamp,
        "sign_method" => "HMAC-SHA256",
        "access_token" => @tuya_service.instance_variable_get(:@access_token)
      }

      Rails.logger.info("Door Lock Logs - URI: #{uri}")
      Rails.logger.info("Door Lock Logs - Headers: #{headers.inspect}")

      # Gửi request
      request = Net::HTTP::Get.new(uri)

      # Thêm các header
      headers.each do |key, value|
        request[key] = value
      end

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.open_timeout = 10
        http.read_timeout = 30
        http.request(request)
      end

      # Xử lý response
      result = JSON.parse(response.body)
      Rails.logger.info("Door Lock Logs response: #{result}")

      if result["success"]
        logs_data = result["result"] || {}
        records = logs_data["logs"] || []

        {
          records: format_unlock_records_from_api(records),
          count: logs_data["total"] || records.size,
          has_more: (logs_data["total"] || 0) > records.size,
          raw_data: logs_data
        }
      else
        Rails.logger.error("Failed to get door lock logs: #{result["msg"]}")
        { error: result["msg"] || "Không thể lấy lịch sử mở khóa", records: [] }
      end
    rescue => e
      Rails.logger.error("Door Lock Logs error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
      { error: e.message, records: [] }
    end
  end

  # Lọc các logs liên quan đến việc mở/khóa cửa
  def filter_unlock_logs(logs)
    # Các từ khóa thường xuất hiện trong logs liên quan đến mở/khóa cửa
    unlock_keywords = [
      "unlock", "lock", "open", "close",
      "mở", "khóa", "cửa", "door",
      "fingerprint", "password", "card", "key"
    ]

    logs.select do |log|
      # Kiểm tra nếu log có code là unlock/lock hoặc liên quan
      if log["code"] && (log["code"].to_s.include?("unlock") || log["code"].to_s.include?("lock") ||
                        log["code"].to_s.include?("door") || log["code"].to_s.include?("open"))
        true
      # Kiểm tra nếu giá trị log chứa từ khóa liên quan đến mở/khóa
      elsif log["value"].is_a?(String)
        unlock_keywords.any? { |keyword| log["value"].to_s.downcase.include?(keyword.downcase) }
      # Kiểm tra nếu value là hash và có các thuộc tính liên quan
      elsif log["value"].is_a?(Hash)
        check_hash_for_unlock_keywords(log["value"], unlock_keywords)
      else
        false
      end
    end
  end

  # Kiểm tra hash có chứa từ khóa liên quan đến mở/khóa cửa
  def check_hash_for_unlock_keywords(hash, keywords)
    return false unless hash.is_a?(Hash)

    # Kiểm tra tất cả các key và value
    hash.any? do |key, value|
      # Nếu key chứa từ khóa
      key_match = keywords.any? { |keyword| key.to_s.downcase.include?(keyword.downcase) }

      # Nếu value là string và chứa từ khóa
      value_match = if value.is_a?(String)
        keywords.any? { |keyword| value.downcase.include?(keyword.downcase) }
      # Nếu value là hash, kiểm tra đệ quy
      elsif value.is_a?(Hash)
        check_hash_for_unlock_keywords(value, keywords)
      # Nếu value là array, kiểm tra từng phần tử
      elsif value.is_a?(Array)
        value.any? { |v| v.is_a?(Hash) ? check_hash_for_unlock_keywords(v, keywords) : keywords.any? { |keyword| v.to_s.downcase.include?(keyword.downcase) } }
      else
        false
      end

      key_match || value_match
    end
  end

  # Lấy danh sách mật khẩu - sử dụng API chuyên biệt
  def get_password_list(device_id)
    path = DOOR_LOCK_ENDPOINTS[:passwords] % { device_id: device_id }
    result = door_lock_api_call("GET", path)

    if result && result[:success]
      result[:data] || []
    else
      # Fallback: thử dùng commands API
      command_result = command_device(device_id, LOCK_CODES[:get_password_records])
      command_result[:error].present? ? { error: command_result[:error] } : command_result
    end
  end

  # Thêm mật khẩu mới - sử dụng API chuyên biệt
  def add_password(device_id, password_data)
    path = DOOR_LOCK_ENDPOINTS[:passwords] % { device_id: device_id }

    # Chuẩn bị dữ liệu theo format API mới
    body_data = {
      password: password_data[:password],
      name: password_data[:name] || "User",
      effective_time: password_data[:effective_time] || (Time.now.to_i * 1000),
      invalid_time: password_data[:invalid_time] || (Time.now + 1.year).to_i * 1000,
      type: password_data[:type] || "permanent" # permanent / temporary
    }

    result = door_lock_api_call("POST", path, body_data)

    if result && result[:success]
      { success: true, password_id: result[:data]&.dig("password_id") }
    else
      # Fallback: thử dùng commands API
      command_result = command_device(device_id, LOCK_CODES[:add_password], password_data)
      command_result[:error].present? ? { error: command_result[:error], success: false } : { success: true }
    end
  end

  # Xóa mật khẩu - sử dụng API chuyên biệt
  def delete_password(device_id, password_id)
    path = DOOR_LOCK_ENDPOINTS[:password] % { device_id: device_id, password_id: password_id }
    result = door_lock_api_call("DELETE", path)

    if result && result[:success]
      { success: true }
    else
      # Fallback: thử dùng commands API
      command_result = command_device(device_id, LOCK_CODES[:delete_password], { password_id: password_id })
      command_result[:error].present? ? { error: command_result[:error], success: false } : { success: true }
    end
  end

  # Cập nhật mật khẩu - sử dụng API chuyên biệt
  def update_password(device_id, password_id, password_data)
    path = DOOR_LOCK_ENDPOINTS[:password] % { device_id: device_id, password_id: password_id }

    # Chuẩn bị dữ liệu theo format API mới
    body_data = {
      name: password_data[:name],
      effective_time: password_data[:effective_time],
      invalid_time: password_data[:invalid_time]
    }.compact # Chỉ giữ lại các giá trị không nil

    result = door_lock_api_call("PUT", path, body_data)

    if result && result[:success]
      { success: true }
    else
      # Fallback: thử dùng commands API
      password_data[:password_id] = password_id
      command_result = command_device(device_id, LOCK_CODES[:update_password], password_data)
      command_result[:error].present? ? { error: command_result[:error], success: false } : { success: true }
    end
  end

  # Lấy danh sách người dùng của khóa
  def get_lock_users(device_id, page_no = 1, page_size = 20)
    begin
      # Đảm bảo đã có token xác thực
      @tuya_service.get_access_token unless @tuya_service.instance_variable_get(:@access_token)

      # Chuẩn bị các tham số
      timestamp = @tuya_service.generate_timestamp

      # Sử dụng endpoint cho users
      path = DOOR_LOCK_ENDPOINTS[:users] % { device_id: device_id }

      # Tham số truy vấn
      query_params = {
        page_no: page_no,
        page_size: page_size
      }

      # Sắp xếp tham số để tạo query string
      query_params = query_params.sort.to_h
      query = URI.encode_www_form(query_params)

      # Tạo URI đầy đủ
      uri = URI("#{@tuya_service.instance_variable_get(:@api_endpoint)}#{path}?#{query}")

      # Tạo chuỗi để ký
      string_to_sign = @tuya_service.create_string_to_sign("GET", path, query)

      # Tạo chữ ký
      sign = @tuya_service.generate_sign(
        string_to_sign,
        timestamp,
        @tuya_service.instance_variable_get(:@access_token)
      )

      # Chuẩn bị headers
      headers = {
        "client_id" => @tuya_service.instance_variable_get(:@client_id),
        "sign" => sign,
        "t" => timestamp,
        "sign_method" => "HMAC-SHA256",
        "access_token" => @tuya_service.instance_variable_get(:@access_token)
      }

      Rails.logger.info("Lock Users API Call - URI: #{uri}")
      Rails.logger.info("Lock Users API Call - Headers: #{headers.inspect}")

      # Gửi request
      request = Net::HTTP::Get.new(uri)

      # Thêm các header
      headers.each do |key, value|
        request[key] = value
      end

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.open_timeout = 10
        http.read_timeout = 30
        http.request(request)
      end

      # Xử lý response
      result = JSON.parse(response.body)
      Rails.logger.info("Lock Users API response: #{result}")

      if result["success"]
        # Phần này chính là nơi xảy ra lỗi - cần xử lý cấu trúc response đúng
        # API trả về một mảng trực tiếp trong trường "result" thay vì một object có trường "list"
        users = result["result"]
        # Kiểm tra xem result có phải là mảng không
        if users.is_a?(Array)
          users_list = users
          total = users.size
        else
          # Trường hợp API thay đổi và trả về cấu trúc có trường "list"
          users_list = users["list"] || []
          total = users["total"] || users_list.size
        end

        {
          users: format_lock_users(users_list),
          count: total,
          has_more: false, # Không có thông tin phân trang rõ ràng từ API
          page_no: page_no,
          page_size: page_size,
          raw_data: users
        }
      else
        Rails.logger.error("Failed to get lock users: #{result["msg"]}")
        { error: result["msg"] || "Không thể lấy danh sách người dùng", users: [] }
      end
    rescue => e
      Rails.logger.error("Lock Users API error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
      { error: e.message, users: [] }
    end
  end

  private

  # Phương thức chung để gọi API khóa cửa
  def door_lock_api_call(method, path, body_data = nil)
    begin
      # Đảm bảo đã có token xác thực
      @tuya_service.get_access_token unless @tuya_service.instance_variable_get(:@access_token)

      # Chuẩn bị các tham số
      timestamp = @tuya_service.generate_timestamp

      # Tạo chuỗi để ký
      string_to_sign = @tuya_service.create_string_to_sign(method, path)

      # Tạo chữ ký
      sign = @tuya_service.generate_sign(
        string_to_sign,
        timestamp,
        @tuya_service.instance_variable_get(:@access_token)
      )

      # Chuẩn bị headers
      headers = {
        "client_id" => @tuya_service.instance_variable_get(:@client_id),
        "sign" => sign,
        "t" => timestamp,
        "sign_method" => "HMAC-SHA256",
        "access_token" => @tuya_service.instance_variable_get(:@access_token)
      }

      # Thêm Content-Type nếu có body
      headers["Content-Type"] = "application/json" if body_data

      # Chuẩn bị URI
      uri = URI("#{@tuya_service.instance_variable_get(:@api_endpoint)}#{path}")

      # Gửi request
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 30

      # Tạo request tương ứng với method
      request = case method.upcase
      when "GET"
          Net::HTTP::Get.new(uri.request_uri)
      when "POST"
          Net::HTTP::Post.new(uri.request_uri)
      when "PUT"
          Net::HTTP::Put.new(uri.request_uri)
      when "DELETE"
          Net::HTTP::Delete.new(uri.request_uri)
      else
          raise "HTTP method not supported: #{method}"
      end

      # Thêm các header
      headers.each do |key, value|
        request[key] = value
      end

      # Thêm body nếu có
      if body_data
        request.body = body_data.to_json
      end

      # Log thông tin request
      Rails.logger.info("Door Lock API Call (#{method}) - URI: #{uri}")
      Rails.logger.info("Door Lock API Call - Headers: #{headers.inspect}")
      Rails.logger.info("Door Lock API Call - Body: #{request.body}") if request.body

      # Gửi request và lấy response
      response = http.request(request)

      # Xử lý response
      begin
        result = JSON.parse(response.body)
        Rails.logger.info("Door Lock API response: #{result}")

        if result["success"]
          {
            success: true,
            data: result["result"],
            code: result["code"],
            msg: result["msg"]
          }
        else
          {
            success: false,
            error: result["msg"] || "Không thành công",
            code: result["code"]
          }
        end
      rescue JSON::ParserError => e
        Rails.logger.error("Failed to parse Door Lock API response: #{e.message}")
        Rails.logger.error("Response body: #{response.body}")
        { success: false, error: "Không thể xử lý phản hồi từ máy chủ" }
      end
    rescue => e
      Rails.logger.error("Door Lock API error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
      { success: false, error: e.message }
    end
  end

  # Giữ phương thức này để tương thích ngược
  def command_device(device_id, command, data = {})
    begin
      # Đảm bảo đã có token xác thực
      @tuya_service.get_access_token unless @tuya_service.instance_variable_get(:@access_token)

      # Chuẩn bị dữ liệu
      timestamp = @tuya_service.generate_timestamp
      path = "/v1.0/devices/#{device_id}/commands"

      # Chuẩn bị commands dựa trên loại lệnh
      commands = build_command(command, data)

      # Tạo body request
      body = { commands: commands }.to_json

      # Tạo chuỗi để ký
      string_to_sign = @tuya_service.create_string_to_sign("POST", path)

      # Tạo chữ ký
      sign = @tuya_service.generate_sign(
        string_to_sign,
        timestamp,
        @tuya_service.instance_variable_get(:@access_token)
      )

      # Chuẩn bị headers
      headers = {
        "client_id" => @tuya_service.instance_variable_get(:@client_id),
        "sign" => sign,
        "t" => timestamp,
        "sign_method" => "HMAC-SHA256",
        "access_token" => @tuya_service.instance_variable_get(:@access_token),
        "Content-Type" => "application/json"
      }

      # Chuẩn bị URI
      uri = URI("#{@tuya_service.instance_variable_get(:@api_endpoint)}#{path}")

      # Gửi request
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri.path, headers)
      request.body = body

      Rails.logger.info("Smart Lock Command - URI: #{uri}")
      Rails.logger.info("Smart Lock Command - Headers: #{headers.inspect}")
      Rails.logger.info("Smart Lock Command - Body: #{body}")

      response = http.request(request)

      # Xử lý response
      begin
        result = JSON.parse(response.body)
        Rails.logger.info("Smart Lock Command response: #{result}")

        if result["success"]
          result["result"] || { success: true }
        else
          { error: result["msg"] || "Không thành công", success: false }
        end
      rescue JSON::ParserError => e
        Rails.logger.error("Failed to parse Smart Lock response: #{e.message}")
        Rails.logger.error("Response body: #{response.body}")
        { error: "Không thể xử lý phản hồi từ máy chủ", success: false }
      end
    rescue => e
      Rails.logger.error("Smart Lock command error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      { error: e.message, success: false }
    end
  end

  # Tạo cấu trúc lệnh dựa trên loại lệnh và dữ liệu
  def build_command(command, data)
    case command
    when LOCK_CODES[:open_door]
      [ { code: command, value: true } ]
    when LOCK_CODES[:lock_door]
      [ { code: command, value: true } ]
    when LOCK_CODES[:add_password]
      [ {
        code: command,
        value: {
          password: data[:password],
          name: data[:name] || "User",
          effective_time: data[:effective_time] || (Time.now.to_i * 1000),
          invalid_time: data[:invalid_time] || (Time.now + 1.year).to_i * 1000,
          type: data[:type] || "permanent" # permanent / temporary
        }
      } ]
    when LOCK_CODES[:delete_password]
      [ { code: command, value: { password_id: data[:password_id] } } ]
    when LOCK_CODES[:update_password]
      [ {
        code: command,
        value: {
          password_id: data[:password_id],
          name: data[:name],
          effective_time: data[:effective_time],
          invalid_time: data[:invalid_time]
          # Các thông tin khác tùy theo API hỗ trợ
        }.compact # Chỉ giữ lại các giá trị không nil
      } ]
    else
      [ { code: command, value: data.presence || true } ]
    end
  end

  # Format dữ liệu từ API chuyên biệt cho khóa cửa
  def format_unlock_records_from_api(records)
    records.map do |record|
      # Trích xuất thông tin người mở khóa từ các trường có thể có trong API
      user_name = record["user_name"] || record["username"] || record["user_id"] || "Không xác định"
      unlock_name = record["unlock_name"] || record["open_name"] || user_name

      {
        id: record["id"] || SecureRandom.uuid,
        time: Time.at((record["update_time"] || record["time"] || Time.now.to_f * 1000) / 1000).strftime("%Y-%m-%d %H:%M:%S"),
        user: user_name,
        unlock_name: unlock_name, # Thêm trường unlock_name
        method: determine_unlock_method(record["unlock_method"] || record["method_type"]),
        success: record["success"] != false, # Mặc định thành công trừ khi xác định là thất bại
        raw_data: record
      }
    end
  end

  # Xác định phương thức mở khóa dựa trên mã
  def determine_unlock_method(method_code)
    case method_code.to_s
    when "1", "fingerprint"
      "Vân tay"
    when "2", "password"
      "Mật khẩu"
    when "3", "card"
      "Thẻ"
    when "4", "app"
      "Ứng dụng"
    when "5", "key"
      "Chìa khóa"
    when "6", "remote"
      "Điều khiển từ xa"
    else
      "Phương thức #{method_code}"
    end
  end

  # Format dữ liệu người dùng từ API
  def format_lock_users(users)
    users.map do |user|
      # Log thông tin người dùng để debug
      Rails.logger.debug("Lock user raw data: #{user}")

      # Trích xuất thông tin người dùng
      {
        id: user["uid"] || user["user_id"] || SecureRandom.uuid,
        name: user["name"] || user["nick_name"] || "Người dùng không tên",
        avatar_url: user["avatar"] || user["avatar_url"],
        role: determine_user_role(user["role"] || user["user_role"]),
        status: user["status"] || "active",
        create_time: format_timestamp(user["create_time"]),
        update_time: format_timestamp(user["update_time"]),
        raw_data: user
      }
    end
  end

  # Xác định vai trò người dùng
  def determine_user_role(role_code)
    case role_code.to_s.downcase
    when "admin", "1"
      "Quản trị viên"
    when "member", "2"
      "Thành viên"
    when "guest", "3"
      "Khách"
    else
      "Vai trò: #{role_code}"
    end
  end

  # Format timestamp từ milliseconds sang định dạng ngày giờ
  def format_timestamp(timestamp)
    if timestamp.present?
      Time.at(timestamp.to_i / 1000).strftime("%Y-%m-%d %H:%M:%S")
    else
      nil
    end
  end
end
