class TuyaCloudService
  # Use constants defined in initializer
  def initialize(client_id = nil, secret_key = nil, api_endpoint = nil, time_offset = nil)
    @client_id = client_id || (defined?(TUYA_CLIENT_ID) ? TUYA_CLIENT_ID : ENV["TUYA_CLIENT_ID"])
    @secret_key = secret_key || (defined?(TUYA_SECRET_KEY) ? TUYA_SECRET_KEY : ENV["TUYA_SECRET_KEY"])
    @api_endpoint = api_endpoint || (defined?(TUYA_API_ENDPOINT) ? TUYA_API_ENDPOINT : ENV["TUYA_API_ENDPOINT"])
    @time_offset = time_offset || (defined?(TUYA_TIME_OFFSET) ? TUYA_TIME_OFFSET : 0)
    @access_token = nil
  end

  # Phương thức này giúp debug cấu hình Tuya API
  def debug_configuration
    # Che đi một phần secret key để bảo mật
    masked_key = @secret_key ? "#{@secret_key[0..3]}...#{@secret_key[-4..-1]}" : nil

    adjusted_time = Time.now.to_i + @time_offset

    config_info = {
      client_id: @client_id,
      secret_key: masked_key,
      api_endpoint: @api_endpoint,
      time_offset: @time_offset,
      access_token: @access_token ? "#{@access_token[0..5]}...#{@access_token[-5..-1]}" : nil,
      system_time: Time.now.utc.to_s,
      system_timestamp: Time.now.to_i,
      adjusted_time: Time.at(adjusted_time).utc.to_s,
      adjusted_timestamp: adjusted_time
    }

    config_info
  end

  def validate_configuration
    missing = []
    missing << "TUYA_CLIENT_ID" if @client_id.nil? || @client_id.empty?
    missing << "TUYA_SECRET_KEY" if @secret_key.nil? || @secret_key.empty?
    missing << "TUYA_API_ENDPOINT" if @api_endpoint.nil? || @api_endpoint.empty?

    unless missing.empty?
      raise "Thiếu cấu hình Tuya API: #{missing.join(', ')}. Vui lòng kiểm tra file config/tuya.yml"
    end
  end

  def get_access_token
    validate_configuration

    # Lấy thời gian hiện tại với offset để giải quyết vấn đề thời gian không hợp lệ
    # Tuya API có thể yêu cầu thời gian theo múi giờ UTC
    timestamp = (Time.now.to_f * 1000).to_i.to_s
    str_to_sign = @client_id + timestamp + @secret_key
    sign = Digest::SHA256.hexdigest(str_to_sign)

    uri = URI("#{@api_endpoint}/v1.0/token?grant_type=1")
    request = Net::HTTP::Get.new(uri)
    request["client_id"] = @client_id
    request["sign"] = sign
    request["t"] = timestamp
    request["sign_method"] = "HMAC-SHA256"

    Rails.logger.info("Tuya API request - timestamp: #{timestamp}, client_id: #{@client_id}")

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      # Tăng timeout để tránh lỗi kết nối
      http.open_timeout = 10
      http.read_timeout = 30
      http.request(request)
    end

    begin
      result = JSON.parse(response.body)
      Rails.logger.info("Tuya API response: #{result}")

      if result["success"]
        @access_token = result["result"]["access_token"]
        @access_token
      else
        error_msg = result["msg"]
        Rails.logger.error("Tuya API error: #{error_msg}")

        if error_msg.include?("request time is invalid")
          # Thử lại với hiệu chỉnh thời gian nếu có lỗi thời gian không hợp lệ
          Rails.logger.info("Retrying with adjusted timestamp due to time sync issue")
          return retry_with_adjusted_time
        end

        raise "Failed to get access token: #{error_msg}"
      end
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse Tuya API response: #{e.message}")
      Rails.logger.error("Response body: #{response.body}")
      raise "Failed to parse Tuya API response: #{e.message}"
    end
  end

  def retry_with_adjusted_time
    # Thử lại với timestamp điều chỉnh
    time_offsets = [ -60, 60, -120, 120, -180, 180, -300, 300 ]

    time_offsets.each do |offset|
      begin
        timestamp = (Time.now.to_i + offset).to_s
        str_to_sign = @client_id + timestamp
        sign = OpenSSL::HMAC.hexdigest("SHA256", @secret_key, str_to_sign)

        uri = URI("#{@api_endpoint}/v1.0/token?grant_type=1")
        request = Net::HTTP::Get.new(uri)
        request["client_id"] = @client_id
        request["sign"] = sign
        request["t"] = timestamp
        request["sign_method"] = "HMAC-SHA256"

        Rails.logger.info("Retrying Tuya API request with offset #{offset}s - timestamp: #{timestamp}")

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.open_timeout = 10
          http.read_timeout = 30
          http.request(request)
        end

        result = JSON.parse(response.body)
        if result["success"]
          Rails.logger.info("Success with time offset of #{offset} seconds")
          @access_token = result["result"]["access_token"]
          return @access_token
        end
      rescue => e
        Rails.logger.error("Retry attempt failed with offset #{offset}s: #{e.message}")
      end
    end

    raise "Failed to get access token: Unable to synchronize time with Tuya API server"
  end

  def get_device_info(device_id)
    validate_configuration
    @access_token ||= get_access_token

    timestamp = Time.now.to_i.to_s
    uri = URI("#{@api_endpoint}/v1.0/devices/#{device_id}")

    str_to_sign = [
      "GET",
      "",
      "",
      uri.request_uri,
      timestamp,
      @access_token
    ].join("\n")

    sign = OpenSSL::HMAC.hexdigest("SHA256", @secret_key, str_to_sign)

    request = Net::HTTP::Get.new(uri)
    request["client_id"] = @client_id
    request["access_token"] = @access_token
    request["sign"] = sign
    request["t"] = timestamp
    request["sign_method"] = "HMAC-SHA256"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    JSON.parse(response.body)
  end

  def get_device_functions(device_id)
    validate_configuration
    @access_token ||= get_access_token

    timestamp = Time.now.to_i.to_s
    uri = URI("#{@api_endpoint}/v1.0/devices/#{device_id}/functions")

    str_to_sign = [
      "GET",
      "",
      "",
      uri.request_uri,
      timestamp,
      @access_token
    ].join("\n")

    sign = OpenSSL::HMAC.hexdigest("SHA256", @secret_key, str_to_sign)

    request = Net::HTTP::Get.new(uri)
    request["client_id"] = @client_id
    request["access_token"] = @access_token
    request["sign"] = sign
    request["t"] = timestamp
    request["sign_method"] = "HMAC-SHA256"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    JSON.parse(response.body)
  end

  def get_device_logs(device_id, start_time, end_time, type = "unlock", size = 100)
    validate_configuration
    @access_token ||= get_access_token

    timestamp = Time.now.to_i.to_s
    uri = URI("#{@api_endpoint}/v1.0/devices/#{device_id}/logs")
    uri.query = URI.encode_www_form({
      start_time: start_time.to_i,
      end_time: end_time.to_i,
      type: type,
      size: size
    })

    str_to_sign = [
      "GET",
      "",
      "",
      "#{uri.path}?#{uri.query}",
      timestamp,
      @access_token
    ].join("\n")

    sign = OpenSSL::HMAC.hexdigest("SHA256", @secret_key, str_to_sign)

    request = Net::HTTP::Get.new(uri)
    request["client_id"] = @client_id
    request["access_token"] = @access_token
    request["sign"] = sign
    request["t"] = timestamp
    request["sign_method"] = "HMAC-SHA256"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    JSON.parse(response.body)
  end

  def get_devices(page = 1, size = 100)
    validate_configuration

    begin
      @access_token ||= get_access_token

      timestamp = Time.now.to_i.to_s
      uri = URI("#{@api_endpoint}/v1.0/devices")
      uri.query = URI.encode_www_form({
        page_no: page,
        page_size: size
      })

      str_to_sign = [
        "GET",
        "",
        "",
        "#{uri.path}?#{uri.query}",
        timestamp,
        @access_token
      ].join("\n")

      sign = OpenSSL::HMAC.hexdigest("SHA256", @secret_key, str_to_sign)

      request = Net::HTTP::Get.new(uri)
      request["client_id"] = @client_id
      request["access_token"] = @access_token
      request["sign"] = sign
      request["t"] = timestamp
      request["sign_method"] = "HMAC-SHA256"

      Rails.logger.info("Fetching devices from Tuya API...")

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.open_timeout = 10
        http.read_timeout = 30
        http.request(request)
      end

      result = JSON.parse(response.body)

      if result["success"]
        devices = result["result"]["devices"] || []
        Rails.logger.info("Successfully fetched #{devices.count} devices from Tuya API")
        devices
      else
        error_msg = result["msg"]
        Rails.logger.error("Failed to get devices: #{error_msg}")

        # Nếu token hết hạn, thử lấy token mới
        if error_msg.include?("token is expired") || error_msg.include?("token is invalid")
          Rails.logger.info("Access token expired, refreshing and retrying...")
          @access_token = nil  # Reset token
          @access_token = get_access_token  # Get new token
          return get_devices(page, size)  # Retry with new token
        end

        []
      end
    rescue => e
      Rails.logger.error("Exception when fetching devices: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      []
    end
  end
end
