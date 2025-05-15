class TuyaCloudService
  RETRY_TIME_OFFSETS = [ -60, 60, -120, 120, -180, 180, -300, 300 ].freeze
  TOKEN_CACHE_KEY = "tuya_api_token".freeze
  TOKEN_CACHE_EXPIRY = 23.hours # Để an toàn, đặt thời gian hết hạn cache ít hơn thời gian hết hạn token Tuya (24h)
  REFRESH_TOKEN_CACHE_KEY = "tuya_refresh_token".freeze

  # Use constants defined in initializer
  def initialize(client_id = nil, secret_key = nil, api_endpoint = nil, time_offset = nil, uid = nil)
    @client_id = client_id || (defined?(TUYA_CLIENT_ID) ? TUYA_CLIENT_ID : ENV["TUYA_CLIENT_ID"])
    @secret_key = secret_key || (defined?(TUYA_SECRET_KEY) ? TUYA_SECRET_KEY : ENV["TUYA_SECRET_KEY"])
    @api_endpoint = api_endpoint || (defined?(TUYA_API_ENDPOINT) ? TUYA_API_ENDPOINT : ENV["TUYA_API_ENDPOINT"])
    @time_offset = time_offset || (defined?(TUYA_TIME_OFFSET) ? TUYA_TIME_OFFSET : 0)
    @access_token = nil
    @uid = uid || "az1679473235761VmZH6"  # Sử dụng uid cụ thể nếu được cung cấp, hoặc sử dụng uid mặc định
    Rails.logger.info("Initialize TuyaCloudService with UID: #{@uid}") if @uid.present?
  end

  # Phương thức này giúp debug cấu hình Tuya API
  def debug_configuration
    # Che đi một phần secret key để bảo mật
    masked_key = @secret_key ? "#{@secret_key[0..3]}...#{@secret_key[-4..-1]}" : nil
    adjusted_time = Time.now.to_i + @time_offset

    {
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

  # Helper method để tạo timestamp
  def generate_timestamp(offset = 0)
    ((Time.now.to_f + offset) * 1000).to_i.to_s
  end

  # Helper method để tạo stringToSign
  def create_string_to_sign(method, path, query_string = nil)
    path_with_query = query_string ? "#{path}?#{query_string}" : path
    "#{method}\n" +
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855\n" +
    "\n" +
    path_with_query
  end

  # Helper method để tạo chữ ký
  def generate_sign(string_to_sign, timestamp, token = nil)
    # In ra các tham số gửi vào để debug ở cấp độ debug
    log_debug_params(string_to_sign, timestamp, token)

    # Các thành phần đầu vào cho phần tính toán chữ ký
    client_id = @client_id
    secret = @secret_key

    str = if string_to_sign.include?("/logs")
      # Đặc biệt cho endpoint logs - thứ tự khác theo tài liệu Tuya
      Rails.logger.info("Using SPECIAL sign calculation for logs endpoint")
      log_debug_logs_endpoint_sign_params(client_id, token, timestamp, string_to_sign)

      client_id.to_s +
      (token ? token.to_s : "") +
      timestamp.to_s +
      string_to_sign.to_s
    else
      # Xử lý thông thường cho các endpoint khác
      if token
        # Business API: client_id + access_token + timestamp + stringToSign
        client_id + token + timestamp + string_to_sign
      else
        # Token API: client_id + timestamp + stringToSign
        client_id + timestamp + string_to_sign
      end
    end

    Rails.logger.debug("generate_sign - final string: #{str.inspect}")

    # Sử dụng HMAC-SHA256 để tạo chữ ký và chuyển thành chữ HOA
    sign = OpenSSL::HMAC.hexdigest("SHA256", secret, str).upcase
    Rails.logger.debug("generate_sign - generated sign: #{sign}")

    sign
  end

  # Helper method để tạo và gửi request API
  def send_api_request(uri, headers, log_prefix = "API")
    request = Net::HTTP::Get.new(uri)

    # Thêm các header
    headers.each do |key, value|
      request[key] = value
    end

    Rails.logger.info("#{log_prefix} - URI: #{uri}")
    Rails.logger.info("#{log_prefix} request - Headers: #{headers}")

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.open_timeout = 10
      http.read_timeout = 30
      http.request(request)
    end

    begin
      result = JSON.parse(response.body)
      Rails.logger.info("#{log_prefix} response: #{result}")
      result
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse #{log_prefix} response: #{e.message}")
      Rails.logger.error("Response body: #{response.body}")
      raise "Failed to parse #{log_prefix} response: #{e.message}"
    end
  end

  def get_access_token(force_refresh = false)
    validate_configuration

    # Tạo cache key dựa trên client_id để hỗ trợ nhiều tài khoản Tuya (nếu cần)
    cache_key = "#{TOKEN_CACHE_KEY}_#{@client_id}"

    # Nếu không bắt buộc làm mới và token đã được lưu trong cache
    # hoặc đã được khởi tạo trong instance hiện tại, thì sử dụng token đó
    unless force_refresh
      if @access_token.nil?
        cached_data = Rails.cache.read(cache_key)
        if cached_data
          Rails.logger.info("Using cached Tuya API token")
          @access_token = cached_data[:token]
          @refresh_token = cached_data[:refresh_token]
          @uid = cached_data[:uid] if cached_data[:uid].present?
          return @access_token
        end
      else
        return @access_token
      end
    end

    # Nếu có refresh token và không bắt buộc force_refresh, thử làm mới token
    if !force_refresh && @refresh_token.present?
      begin
        refreshed_token = refresh_access_token(@refresh_token)
        return refreshed_token if refreshed_token
      rescue => e
        Rails.logger.error("Error refreshing token: #{e.message}, will get new token instead")
      end
    end

    # Lấy token mới từ Tuya API
    timestamp = generate_timestamp()
    path = "/v1.0/token"
    query = "grant_type=1"
    string_to_sign = create_string_to_sign("GET", path, query)
    sign = generate_sign(string_to_sign, timestamp)

    log_token_request_params(timestamp, string_to_sign, sign)

    uri = URI("#{@api_endpoint}#{path}?#{query}")
    headers = build_headers(timestamp, sign)

    result = send_api_request(uri, headers, "Token API")

    handle_token_response(result, cache_key)
  end

  def refresh_access_token(refresh_token)
    validate_configuration

    Rails.logger.info("Refreshing access token using refresh token")

    timestamp = generate_timestamp()
    path = "/v1.0/token/#{refresh_token}"
    string_to_sign = create_string_to_sign("GET", path)
    sign = generate_sign(string_to_sign, timestamp)

    uri = URI("#{@api_endpoint}#{path}")
    headers = build_headers(timestamp, sign)

    begin
      result = send_api_request(uri, headers, "Refresh Token API")

      if result["success"]
        @access_token = result["result"]["access_token"]
        @refresh_token = result["result"]["refresh_token"]
        # @uid = result["result"]["uid"] if result["result"]["uid"].present?

        # Lưu token mới vào cache
        cache_key = "#{TOKEN_CACHE_KEY}_#{@client_id}"
        Rails.cache.write(
          cache_key,
          {
            token: @access_token,
            refresh_token: @refresh_token,
            uid: @uid
          },
          expires_in: TOKEN_CACHE_EXPIRY
        )

        Rails.logger.info("Successfully refreshed Tuya API token")
        @access_token
      else
        error_msg = result["msg"]
        Rails.logger.error("Failed to refresh token: #{error_msg}")
        nil
      end
    rescue => e
      Rails.logger.error("Exception when refreshing token: #{e.message}")
      nil
    end
  end

  def handle_token_response(result, cache_key = nil)
    if result["success"]
      @access_token = result["result"]["access_token"]
      @refresh_token = result["result"]["refresh_token"] if result["result"]["refresh_token"].present?
      # @uid = result["result"]["uid"] if result["result"]["uid"].present?

      # Lưu token vào cache nếu cache_key được cung cấp
      if cache_key
        Rails.cache.write(
          cache_key,
          {
            token: @access_token,
            refresh_token: @refresh_token,
            uid: @uid
          },
          expires_in: TOKEN_CACHE_EXPIRY
        )
        Rails.logger.info("Stored Tuya API token in cache, expires in #{TOKEN_CACHE_EXPIRY.to_i / 3600} hours")
      end

      @access_token
    else
      error_msg = result["msg"]
      Rails.logger.error("Tuya API error: #{error_msg}")

      if error_msg.include?("request time is invalid")
        Rails.logger.info("Retrying with adjusted timestamp due to time sync issue")
        return retry_with_adjusted_time
      end

      raise "Failed to get access token: #{error_msg}"
    end
  end

  def retry_with_adjusted_time
    RETRY_TIME_OFFSETS.each do |offset|
      begin
        timestamp = generate_timestamp(offset)
        path = "/v1.0/token"
        query = "grant_type=1"
        string_to_sign = create_string_to_sign("GET", path, query)
        sign = generate_sign(string_to_sign, timestamp)

        log_retry_token_params(timestamp, offset, string_to_sign)

        uri = URI("#{@api_endpoint}#{path}?#{query}")
        headers = build_headers(timestamp, sign)

        Rails.logger.info("Retrying Tuya API request with offset #{offset}s - timestamp: #{timestamp}")
        result = send_api_request(uri, headers, "Retry Token API")

        if result["success"]
          Rails.logger.info("Success with time offset of #{offset} seconds")
          @access_token = result["result"]["access_token"]
          # @uid = result["result"]["uid"] if result["result"]["uid"].present?

          # Lưu token và uid vào cache
          cache_key = "#{TOKEN_CACHE_KEY}_#{@client_id}"
          Rails.cache.write(cache_key, { token: @access_token, uid: @uid }, expires_in: TOKEN_CACHE_EXPIRY)
          Rails.logger.info("Stored Tuya API token in cache after time adjustment")

          return @access_token
        end
      rescue => e
        Rails.logger.error("Retry attempt failed with offset #{offset}s: #{e.message}")
      end
    end

    raise "Failed to get access token: Unable to synchronize time with Tuya API server"
  end

  # Phương thức mới để đảm bảo rằng chúng ta có token
  def ensure_access_token
    @access_token ||= get_access_token
  end

  def get_device_info(device_id)
    validate_configuration
    ensure_access_token

    timestamp = generate_timestamp()
    path = "/v1.0/devices/#{device_id}"
    string_to_sign = create_string_to_sign("GET", path)
    sign = generate_sign(string_to_sign, timestamp, @access_token)

    uri = URI("#{@api_endpoint}#{path}")
    headers = build_headers(timestamp, sign, @access_token)

    Rails.logger.info("Fetching device info for device_id: #{device_id}")
    result = send_api_request(uri, headers, "Device Info API")

    handle_device_info_response(result, device_id)
  end

  def handle_device_info_response(result, device_id)
    if result["success"]
      device_info = result["result"]
      Rails.logger.info("Successfully fetched device info: #{device_info['name']}")
      device_info
    else
      error_msg = result["msg"]
      Rails.logger.error("Failed to get device info: #{error_msg}")

      if token_expired?(error_msg)
        refresh_and_retry_device_info(device_id)
      elsif time_sync_error?(error_msg)
        retry_get_device_info_with_adjusted_time(device_id)
      else
        {}
      end
    end
  end

  # Phương thức để thử lại lấy thông tin thiết bị với điều chỉnh thời gian
  def retry_get_device_info_with_adjusted_time(device_id)
    RETRY_TIME_OFFSETS.each do |offset|
      begin
        validate_configuration
        @access_token ||= get_access_token

        timestamp = generate_timestamp(offset)
        path = "/v1.0/devices/#{device_id}"
        string_to_sign = create_string_to_sign("GET", path)
        sign = generate_sign(string_to_sign, timestamp, @access_token)

        uri = URI("#{@api_endpoint}#{path}")
        headers = build_headers(timestamp, sign, @access_token)

        Rails.logger.info("Retrying fetch device info with offset #{offset}s - timestamp: #{timestamp}")
        result = send_api_request(uri, headers, "Retry Device Info API")

        if result["success"]
          device_info = result["result"]
          Rails.logger.info("Successfully fetched device info with time offset #{offset}s")
          return device_info
        else
          error_msg = result["msg"]
          Rails.logger.error("Retry with offset #{offset}s failed: #{error_msg}")
        end
      rescue => e
        Rails.logger.error("Retry attempt for device info failed with offset #{offset}s: #{e.message}")
      end
    end

    Rails.logger.error("All retry attempts for fetching device info failed")
    {}
  end

  def get_device_functions(device_id)
    validate_configuration
    @access_token ||= get_access_token

    path = "/v1.0/devices/#{device_id}/functions"
    timestamp = generate_timestamp()
    string_to_sign = create_string_to_sign("GET", path)
    sign = generate_sign(string_to_sign, timestamp, @access_token)

    uri = URI("#{@api_endpoint}#{path}")
    headers = build_headers(timestamp, sign, @access_token)

    result = send_api_request(uri, headers, "Device Functions API")
    result["success"] ? result["result"] : {}
  end

  # Dedicated method for device logs to handle the unique signing requirements
  def get_device_logs(device_id, *args)
    validate_configuration
    @access_token ||= get_access_token

    options = process_logs_options(args)
    path = "/v1.0/devices/#{device_id}/logs"
    query_params = build_logs_query_params(options)
    sorted_query = build_sorted_query_string(query_params)
    request_url = "#{path}?#{sorted_query}"

    timestamp = generate_timestamp()
    string_to_sign = build_logs_string_to_sign(request_url)
    sign = generate_logs_sign(string_to_sign, timestamp)

    uri = URI("#{@api_endpoint}#{request_url}")
    headers = build_headers(timestamp, sign, @access_token)

    Rails.logger.info("Fetching device logs for device_id: #{device_id}")

    begin
      result = send_api_request(uri, headers, "Device Logs API")
      handle_logs_response(result, device_id, options)
    rescue => e
      handle_logs_exception(e)
    end
  end

  # Helper methods for get_device_logs
  def process_logs_options(args)
    options = {}
    if args.length > 0
      if args[0].is_a?(Hash)
        options = args[0]
      else
        options = {
          start_time: args[0] || 0,
          end_time: args[1] || (Time.now.to_f * 1000).to_i,
          type: args[2] || "1,2",
          size: args[3] || 20
        }
      end
    end

    # Default parameters
    {
      start_time: (Time.now.to_f * 1000).to_i - 7 * 24 * 60 * 60 * 1000, # 7 days ago
      end_time: (Time.now.to_f * 1000).to_i,
      type: "1",
      size: 50
    }.merge(options)
  end

  def convert_time_params(options)
    [ :start_time, :end_time ].each do |key|
      if options[key].is_a?(Time) || options[key].is_a?(DateTime)
        options[key] = (options[key].to_time.to_f * 1000).to_i
      elsif options[key].is_a?(String)
        begin
          options[key] = (Time.parse(options[key]).to_f * 1000).to_i
        rescue
          # Keep as is if parsing fails
        end
      end
    end
    options
  end

  def build_logs_query_params(options)
    options = convert_time_params(options)

    query_params = {
      start_time: options[:start_time],
      end_time: options[:end_time],
      type: options[:type],
      size: options[:size]
    }

    # Add optional parameters
    query_params[:codes] = options[:codes] if options[:codes].present?
    query_params[:start_row_key] = options[:start_row_key] if options[:start_row_key].present?

    # Sort params ALPHABETICALLY - required by Tuya
    query_params.sort.to_h
  end

  def build_sorted_query_string(sorted_query_params)
    query_parts = []
    sorted_query_params.each do |key, value|
      query_parts << "#{key}=#{value}"
    end
    query_parts.join("&")
  end

  def build_logs_string_to_sign(request_url)
    "GET\n" +
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855\n" +
    "\n" +
    "#{request_url}"
  end

  def generate_logs_sign(string_to_sign, timestamp)
    sign_str = @client_id + @access_token + timestamp + string_to_sign

    Rails.logger.info("Device Logs API - Timestamp: #{timestamp}")
    Rails.logger.info("Device Logs API - String to sign: #{sign_str.inspect}")

    OpenSSL::HMAC.hexdigest("SHA256", @secret_key, sign_str).upcase
  end

  def handle_logs_response(result, device_id, options)
    if result["success"]
      logs = result["result"]["logs"] || []
      Rails.logger.info("Successfully fetched #{logs.count} logs")

      {
        logs: logs,
        has_next: result["result"]["has_next"],
        device_id: result["result"]["device_id"],
        current_row_key: result["result"]["current_row_key"],
        next_row_key: result["result"]["next_row_key"],
        count: result["result"]["count"]
      }
    else
      error_msg = result["msg"]
      Rails.logger.error("Failed to get device logs: #{error_msg}")

      if token_expired?(error_msg)
        refresh_and_retry_logs(device_id, options)
      elsif time_sync_error?(error_msg)
        try_logs_with_different_timestamps(device_id, options)
      else
        { error: error_msg, logs: [] }
      end
    end
  end

  def handle_logs_exception(exception)
    Rails.logger.error("Exception in device logs API: #{exception.message}")
    Rails.logger.error(exception.backtrace.join("\n"))
    { error: exception.message, logs: [] }
  end

  def refresh_and_retry_logs(device_id, options)
    Rails.logger.info("Access token expired, refreshing and retrying...")
    @access_token = nil
    @access_token = get_access_token
    get_device_logs(device_id, options)
  end

  # Try logs API with different timestamps to handle time sync issues
  def try_logs_with_different_timestamps(device_id, options)
    [ -1, 1, -2, 2, -5, 5, -10, 10 ].each do |offset_seconds|
      begin
        Rails.logger.info("Trying logs API with #{offset_seconds}s time offset")

        # Setup API call
        path = "/v1.0/devices/#{device_id}/logs"
        query_params = build_logs_query_params(options)
        sorted_query = build_sorted_query_string(query_params)
        request_url = "#{path}?#{sorted_query}"

        # Generate timestamp with offset
        timestamp = ((Time.now.to_f + offset_seconds) * 1000).to_i.to_s

        # Build canonical request and sign string
        string_to_sign = build_logs_string_to_sign(request_url)
        sign_str = @client_id + @access_token + timestamp + string_to_sign
        sign = OpenSSL::HMAC.hexdigest("SHA256", @secret_key, sign_str).upcase

        # Build URI
        uri = URI("#{@api_endpoint}#{request_url}")

        # Setup headers
        headers = build_headers(timestamp, sign, @access_token)

        # Send request
        Rails.logger.info("Retry logs API with offset #{offset_seconds}s")

        result = send_api_request(uri, headers, "Retry Logs API")

        if result["success"]
          logs = result["result"]["logs"] || []
          Rails.logger.info("Successfully fetched #{logs.count} logs with offset #{offset_seconds}s")

          return {
            logs: logs,
            has_next: result["result"]["has_next"],
            device_id: result["result"]["device_id"],
            current_row_key: result["result"]["current_row_key"],
            next_row_key: result["result"]["next_row_key"],
            count: result["result"]["count"]
          }
        else
          Rails.logger.error("Retry failed with offset #{offset_seconds}s: #{result["msg"]}")
        end
      rescue => e
        Rails.logger.error("Exception in retry with offset #{offset_seconds}s: #{e.message}")
      end
    end

    # All retries failed
    Rails.logger.error("All time offset attempts failed for logs API")
    { logs: [], error: "Failed to synchronize time with Tuya API server" }
  end

  def get_devices(page_no = 1, page_size = 100, options = {})
    validate_configuration
    @access_token ||= get_access_token

    begin
      timestamp = generate_timestamp()
      path, query_params = build_devices_request_params(page_no, page_size, options)
      query = URI.encode_www_form(query_params)
      uri = URI("#{@api_endpoint}#{path}?#{query}")

      # Tạo stringToSign và chữ ký
      string_to_sign = create_string_to_sign("GET", path, query)
      sign = generate_sign(string_to_sign, timestamp, @access_token)

      Rails.logger.info("Devices API - Timestamp (ms): #{timestamp}")
      Rails.logger.info("Devices API - StringToSign: #{string_to_sign.gsub("\n", "\\n")}")

      headers = build_headers(timestamp, sign, @access_token)

      Rails.logger.info("Fetching devices from Tuya API...")
      result = send_api_request(uri, headers, "Devices API")

      handle_devices_response(result, page_no, page_size, options)
    rescue => e
      handle_devices_exception(e)
    end
  end

  def build_devices_request_params(page_no, page_size, options)
    if options[:user_id].present?
      # Endpoint để lấy danh sách thiết bị của một người dùng cụ thể
      path = "/v1.0/users/#{options[:user_id]}/devices"
      query_params = { page_no: page_no, page_size: page_size }
    else
      # Endpoint để lấy tất cả thiết bị
      path = "/v1.0/devices"
      query_params = { page_no: page_no, page_size: page_size }

      # Thêm các tham số tùy chọn nếu được cung cấp
      query_params[:schema] = options[:schema] if options[:schema].present?
      query_params[:product_id] = options[:product_id] if options[:product_id].present?
      query_params[:device_ids] = options[:device_ids] if options[:device_ids].present?

      # Nếu không có tham số nào được cung cấp, sử dụng user endpoint
      if !options[:schema].present? && !options[:product_id].present? && !options[:device_ids].present?
        Rails.logger.info("No device query parameters provided, using uid from token response if available")

        if @uid.present?
          return [ "/v1.0/users/#{@uid}/devices", { page_no: page_no, page_size: page_size } ]
        else
          query_params[:schema] = "tuyaSmart" # Schema mặc định
        end
      end
    end

    [ path, query_params ]
  end

  def handle_devices_response(result, page_no, page_size, options)
    if result["success"]
      # Xử lý kết quả tùy thuộc vào loại endpoint
      devices = if options[:user_id].present?
        result["result"] || []
      else
        result["result"]["devices"] || []
      end

      Rails.logger.info("Successfully fetched #{devices.count} devices from Tuya API")
      devices
    else
      error_msg = result["msg"]
      Rails.logger.error("Failed to get devices: #{error_msg}")

      # Xử lý các trường hợp lỗi phổ biến
      if token_expired?(error_msg)
        refresh_and_retry_devices(page_no, page_size, options)
      elsif time_sync_error?(error_msg)
        retry_get_devices_with_adjusted_time(page_no, page_size, options)
      elsif permission_denied?(error_msg) && options[:schema] == "tuyaSmart"
        handle_permission_deny(page_no, page_size, options)
      else
        []
      end
    end
  end

  def handle_devices_exception(exception)
    Rails.logger.error("Exception when fetching devices: #{exception.class} - #{exception.message}")
    Rails.logger.error(exception.backtrace.join("\n"))
    []
  end

  def refresh_and_retry_devices(page_no, page_size, options)
    Rails.logger.info("Access token expired, refreshing and retrying...")
    @access_token = nil
    @access_token = get_access_token
    get_devices(page_no, page_size, options)
  end

  # Helper method để xử lý lỗi permission deny
  def handle_permission_deny(page_no, page_size, options)
    Rails.logger.info("Permission denied for schema #{options[:schema]}, trying alternatives...")

    # Thử với user endpoint
    if @uid.present?
      Rails.logger.info("Trying user endpoint with UID: #{@uid}")
      return get_devices(page_no, page_size, { user_id: @uid })
    end

    # Thử với các schema phổ biến khác
    schema_options = [ "tuya", "smart_life", "tuyaUs", "tuyaCN" ]
    Rails.logger.info("Trying alternative schemas: #{schema_options}")

    schema_options.each do |schema|
      begin
        Rails.logger.info("Trying with schema: #{schema}")
        devices = get_devices(page_no, page_size, { schema: schema })
        return devices if devices.any?
      rescue => e
        Rails.logger.error("Failed with schema #{schema}: #{e.message}")
      end
    end

    []
  end

  def retry_get_devices_with_adjusted_time(page_no = 1, page_size = 100, options = {})
    RETRY_TIME_OFFSETS.each do |offset|
      begin
        validate_configuration
        @access_token ||= get_access_token

        timestamp = generate_timestamp(offset)
        path, query_params = build_devices_request_params(page_no, page_size, options)
        query = URI.encode_www_form(query_params)
        uri = URI("#{@api_endpoint}#{path}?#{query}")

        # Tạo stringToSign và chữ ký
        string_to_sign = create_string_to_sign("GET", path, query)
        sign = generate_sign(string_to_sign, timestamp, @access_token)

        Rails.logger.info("Retry Devices API - Using time offset: #{offset}s")
        Rails.logger.info("Retry Devices API - Timestamp (ms): #{timestamp}")

        headers = build_headers(timestamp, sign, @access_token)

        Rails.logger.info("Retrying fetch devices with offset #{offset}s - timestamp: #{timestamp}")
        result = send_api_request(uri, headers, "Retry Devices API")

        if result["success"]
          # Xử lý kết quả
          devices = if options[:user_id].present?
            result["result"] || []
          else
            result["result"]["devices"] || []
          end

          Rails.logger.info("Successfully fetched #{devices.count} devices from Tuya API with time offset #{offset}s")
          return devices
        else
          error_msg = result["msg"]
          Rails.logger.error("Retry with offset #{offset}s failed: #{error_msg}")
        end
      rescue => e
        Rails.logger.error("Retry attempt for devices failed with offset #{offset}s: #{e.message}")
      end
    end

    Rails.logger.error("All retry attempts for fetching devices failed")
    []
  end

  private

  def token_expired?(error_msg)
    error_msg.include?("token is expired") || error_msg.include?("token is invalid")
  end

  def time_sync_error?(error_msg)
    error_msg.include?("request time is invalid")
  end

  def permission_denied?(error_msg)
    error_msg.include?("permission deny")
  end

  def refresh_and_retry_device_info(device_id)
    Rails.logger.info("Access token expired, refreshing and retrying...")
    @access_token = nil
    @access_token = get_access_token
    get_device_info(device_id)
  end

  def build_headers(timestamp, sign, token = nil)
    headers = {
      "client_id" => @client_id,
      "sign" => sign,
      "t" => timestamp,
      "sign_method" => "HMAC-SHA256"
    }
    headers["access_token"] = token if token
    headers
  end

  def log_debug_params(string_to_sign, timestamp, token)
    Rails.logger.debug("generate_sign input - string_to_sign: #{string_to_sign.inspect}")
    Rails.logger.debug("generate_sign input - timestamp: #{timestamp}")
    Rails.logger.debug("generate_sign input - token: #{token.inspect}")
  end

  def log_debug_logs_endpoint_sign_params(client_id, token, timestamp, string_to_sign)
    Rails.logger.debug("Logs endpoint - step 1 (client_id): #{client_id}")
    Rails.logger.debug("Logs endpoint - step 2 (token): #{token}") if token
    Rails.logger.debug("Logs endpoint - step 3 (timestamp): #{timestamp}")
    Rails.logger.debug("Logs endpoint - step 4 (stringToSign): #{string_to_sign.gsub("\n", "\\n")}")
  end

  def log_token_request_params(timestamp, string_to_sign, sign)
    Rails.logger.info("Timestamp (ms): #{timestamp}")
    Rails.logger.info("StringToSign: #{string_to_sign.gsub("\n", "\\n")}")
    Rails.logger.info("Sign (HMAC-SHA256 in uppercase): #{sign}")
  end

  def log_retry_token_params(timestamp, offset, string_to_sign)
    Rails.logger.info("Retry - Timestamp (ms): #{timestamp}")
    Rails.logger.info("Retry - Using time offset: #{offset}s")
    Rails.logger.info("Retry - String to sign: #{string_to_sign.gsub("\n", "\\n")}")
  end
end
