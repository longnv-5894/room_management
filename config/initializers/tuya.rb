# Configure Tuya Cloud API
begin
  # Load configuration from YAML
  tuya_config = YAML.load_file(Rails.root.join('config', 'tuya.yml'))
  
  if tuya_config && tuya_config['tuya']
    TUYA_CONFIG = tuya_config['tuya']
  
    # Override with environment variables if available
    TUYA_CONFIG['api_endpoint'] = ENV['TUYA_API_ENDPOINT'] if ENV['TUYA_API_ENDPOINT'].present?
    TUYA_CONFIG['client_id'] = ENV['TUYA_CLIENT_ID'] if ENV['TUYA_CLIENT_ID'].present?
    TUYA_CONFIG['secret_key'] = ENV['TUYA_SECRET_KEY'] if ENV['TUYA_SECRET_KEY'].present?
  
    # Set constants for easy access
    TUYA_API_ENDPOINT = TUYA_CONFIG['api_endpoint']
    TUYA_CLIENT_ID = TUYA_CONFIG['client_id']
    TUYA_SECRET_KEY = TUYA_CONFIG['secret_key']
    TUYA_TIME_OFFSET = TUYA_CONFIG['time_offset'] || 0
  
    puts "📱 Loaded Tuya API configuration successfully"
  else
    puts "⚠️ WARNING: Invalid Tuya API configuration format in config/tuya.yml"
  end
rescue => e
  puts "⚠️ WARNING: Failed to load Tuya API configuration: #{e.message}"
end
