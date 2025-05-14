class SmartDevice < ApplicationRecord
  validates :name, presence: true
  validates :device_id, presence: true
  validates :device_type, presence: true
  
  belongs_to :building, optional: true
  
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
      service.get_device_logs(device_id, start_time, end_time)
    rescue => e
      { error: e.message }
    end
  end
  
  def self.device_types
    ['fingerprint_lock', 'smart_lock', 'camera', 'light', 'switch', 'other']
  end
end
