class SmartDevicesController < ApplicationController
  before_action :set_smart_device, only: [ :show, :edit, :update, :destroy, :device_info, :device_functions, :device_logs, :lock_status, :unlock_door, :lock_door, :battery_level, :unlock_records, :password_list, :add_password, :delete_password, :lock_users ]
  before_action :set_building, only: [ :index, :new, :create ]

  def index
    if @building
      @smart_devices = @building.smart_devices
    else
      @smart_devices = SmartDevice.all
    end
  end

  def show
    # Nếu là khóa cửa thông minh, lấy thêm thông tin trạng thái khóa và pin
    if @smart_device.smart_lock?
      @lock_status = @smart_device.get_lock_status
      @battery_level = @smart_device.get_battery_level
    end
  end

  def new
    @smart_device = SmartDevice.new
    @smart_device.building = @building if @building
    @buildings = Building.all
    @device_types = SmartDevice.device_types
    @tuya_devices = fetch_tuya_devices
  end

  def fetch_tuya_devices
    service = TuyaCloudService.new
    begin
      # Debug thông tin cấu hình
      config_info = service.debug_configuration
      Rails.logger.info("Tuya API Config: #{config_info}")

      devices = service.get_devices
      if devices.empty?
        flash.now[:alert] = "Không tìm thấy thiết bị nào trong tài khoản Tuya Cloud. Vui lòng đảm bảo thiết bị đã được thêm vào ứng dụng Smart Life trước."
      end
      devices
    rescue => e
      Rails.logger.error("Failed to fetch Tuya devices: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n")) if e.backtrace

      if e.message.include?("Thiếu cấu hình Tuya API")
        flash.now[:alert] = "#{e.message}. Vui lòng liên hệ quản trị viên để cấu hình kết nối Tuya API."
      elsif e.message.include?("request time is invalid")
        flash.now[:alert] = "Lỗi đồng bộ thời gian với máy chủ Tuya. Hệ thống đang thử nhiều giá trị offset khác nhau."
      elsif e.message.include?("token is expired") || e.message.include?("token is invalid")
        flash.now[:alert] = "Access token đã hết hạn hoặc không hợp lệ. Đang thử lại với token mới."
      else
        flash.now[:alert] = "Không thể lấy dữ liệu thiết bị từ Tuya Cloud: #{e.message}"
      end
      []
    end
  end

  def create
    @smart_device = SmartDevice.new(smart_device_params)
    @smart_device.building = @building if @building && !params[:smart_device][:building_id].present?

    if @smart_device.save
      redirect_to smart_device_path(@smart_device), notice: "Thiết bị thông minh đã được tạo thành công."
    else
      @buildings = Building.all
      @device_types = SmartDevice.device_types
      @tuya_devices = fetch_tuya_devices
      render :new
    end
  end

  def edit
    @buildings = Building.all
    @device_types = SmartDevice.device_types
    @tuya_devices = fetch_tuya_devices
  end

  def update
    if @smart_device.update(smart_device_params)
      redirect_to smart_device_path(@smart_device), notice: "Thiết bị thông minh đã được cập nhật thành công."
    else
      @buildings = Building.all
      @device_types = SmartDevice.device_types
      @tuya_devices = fetch_tuya_devices
      render :edit
    end
  end

  def destroy
    building = @smart_device.building
    @smart_device.destroy

    if params[:redirect_to] == "building" && building.present?
      redirect_to building_path(building), notice: "Thiết bị thông minh đã được xóa thành công."
    elsif building.present?
      redirect_to building_smart_devices_path(building), notice: "Thiết bị thông minh đã được xóa thành công."
    else
      redirect_to smart_devices_path, notice: "Thiết bị thông minh đã được xóa thành công."
    end
  end

  def device_info
    @device_info = @smart_device.fetch_device_info

    respond_to do |format|
      format.html
      format.json { render json: @device_info }
    end
  end

  def device_functions
    @device_functions = @smart_device.fetch_device_functions

    respond_to do |format|
      format.html
      format.json { render json: @device_functions }
    end
  end

  def device_logs
    days = params[:days].present? ? params[:days].to_i : 7
    @device_logs = @smart_device.fetch_device_logs(days)

    respond_to do |format|
      format.html
      format.json { render json: @device_logs }
    end
  end

  def lock_status
    @lock_status = @smart_device.get_lock_status

    respond_to do |format|
      format.html
      format.json { render json: @lock_status }
    end
  end

  def unlock_door
    result = @smart_device.unlock

    respond_to do |format|
      if result[:error].blank?
        format.html { redirect_to @smart_device, notice: "Đã mở khóa thành công." }
        format.json { render json: { success: true, message: "Đã mở khóa thành công" } }
      else
        format.html { redirect_to @smart_device, alert: "Không thể mở khóa: #{result[:error]}" }
        format.json { render json: { success: false, error: result[:error] }, status: :unprocessable_entity }
      end
    end
  end

  def lock_door
    result = @smart_device.lock

    respond_to do |format|
      if result[:error].blank?
        format.html { redirect_to @smart_device, notice: "Đã khóa thành công." }
        format.json { render json: { success: true, message: "Đã khóa thành công" } }
      else
        format.html { redirect_to @smart_device, alert: "Không thể khóa: #{result[:error]}" }
        format.json { render json: { success: false, error: result[:error] }, status: :unprocessable_entity }
      end
    end
  end

  def battery_level
    @battery_level = @smart_device.get_battery_level

    respond_to do |format|
      format.html
      format.json { render json: @battery_level }
    end
  end

  def unlock_records
    days = params[:days].present? ? params[:days].to_i : 7
    page = params[:page].present? ? params[:page].to_i : 1
    page_size = params[:page_size].present? ? params[:page_size].to_i : 50

    # Gọi hàm get_unlock_records đã được cập nhật trong model
    @unlock_records = @smart_device.get_unlock_records(days)

    # Nếu có thêm records và người dùng muốn tải thêm trang tiếp theo
    if params[:load_more].present? && @unlock_records[:has_more] && page > 1
      # Chuẩn bị options truyền vào service
      options = {
        start_time: (Time.now - days.days).to_i * 1000,
        end_time: Time.now.to_i * 1000,
        page_no: page,
        page_size: page_size
      }

      # Gọi service trực tiếp với tham số page_no
      lock_service = TuyaSmartLockService.new
      more_records = lock_service.get_unlock_records(@smart_device.device_id, options)

      if more_records[:success] && more_records[:records].present?
        # Nối thêm records mới vào kết quả hiện tại
        @unlock_records[:records] += more_records[:records]
        @unlock_records[:has_more] = more_records[:has_more]
        @unlock_records[:page_no] = more_records[:page_no]
      end
    end

    respond_to do |format|
      format.html
      format.json { render json: @unlock_records }
    end
  end

  def password_list
    @password_list = @smart_device.get_password_list

    respond_to do |format|
      format.html
      format.json { render json: @password_list }
    end
  end

  def add_password
    password = params[:password]
    name = params[:name]
    options = {}

    options[:start_time] = params[:start_time].to_i * 1000 if params[:start_time].present?
    options[:end_time] = params[:end_time].to_i * 1000 if params[:end_time].present?
    options[:type] = params[:type] if params[:type].present?

    result = @smart_device.add_password(password, name, options)

    respond_to do |format|
      if result[:success]
        format.html { redirect_to password_list_smart_device_path(@smart_device), notice: "Đã thêm mật khẩu thành công." }
        format.json { render json: { success: true } }
      else
        format.html { redirect_to password_list_smart_device_path(@smart_device), alert: "Không thể thêm mật khẩu: #{result[:error]}" }
        format.json { render json: { success: false, error: result[:error] }, status: :unprocessable_entity }
      end
    end
  end

  def delete_password
    password_id = params[:password_id]
    result = @smart_device.delete_password(password_id)

    respond_to do |format|
      if result[:success]
        format.html { redirect_to password_list_smart_device_path(@smart_device), notice: "Đã xóa mật khẩu thành công." }
        format.json { render json: { success: true } }
      else
        format.html { redirect_to password_list_smart_device_path(@smart_device), alert: "Không thể xóa mật khẩu: #{result[:error]}" }
        format.json { render json: { success: false, error: result[:error] }, status: :unprocessable_entity }
      end
    end
  end

  def lock_users
    page = params[:page].present? ? params[:page].to_i : 1
    page_size = params[:page_size].present? ? params[:page_size].to_i : 20
    @lock_users = @smart_device.get_lock_users(page, page_size)

    respond_to do |format|
      format.html
      format.json { render json: @lock_users }
    end
  end

  def debug_api
    time_offset = params[:time_offset].present? ? params[:time_offset].to_i : nil
    service = TuyaCloudService.new(nil, nil, nil, time_offset)
    @config_info = service.debug_configuration

    begin
      @access_token = service.get_access_token
      @success = true
      @error = nil

      if time_offset.present? && time_offset != 0
        flash.now[:success] = "Kết nối thành công với time_offset là #{time_offset}. Bạn có thể cập nhật file config/tuya.yml để sử dụng giá trị này."
      end
    rescue => e
      @success = false
      @error = e.message
      Rails.logger.error("Tuya API debug error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
    end

    respond_to do |format|
      format.html
      format.json { render json: { config: @config_info, success: @success, error: @error } }
    end
  end

  def sync_devices
    service = TuyaCloudService.new

    begin
      devices = service.get_devices

      if devices.empty?
        flash[:alert] = "Không tìm thấy thiết bị nào trong tài khoản Tuya Cloud."
        redirect_to smart_devices_path
        return
      end

      # Count for statistics
      new_devices_count = 0
      updated_devices_count = 0

      # Process each device
      devices.each do |device|
        existing_device = SmartDevice.find_by(device_id: device[:id])

        if existing_device
          # Update existing device if needed
          existing_device.update(
            name: device[:name] || existing_device.name
          )
          updated_devices_count += 1
        else
          # Create new device
          SmartDevice.create(
            name: device[:name] || "New Device",
            device_id: device[:id],
            device_type: device[:category] || "unknown"
          )
          new_devices_count += 1
        end
      end

      flash[:notice] = "Đồng bộ thành công: #{new_devices_count} thiết bị mới, #{updated_devices_count} thiết bị cập nhật."
    rescue => e
      Rails.logger.error("Failed to sync Tuya devices: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
      flash[:alert] = "Lỗi đồng bộ thiết bị: #{e.message}"
    end

    redirect_to smart_devices_path
  end

  private

  def set_smart_device
    @smart_device = SmartDevice.find(params[:id])
  end

  def set_building
    @building = Building.find(params[:building_id]) if params[:building_id]
  end

  def smart_device_params
    params.require(:smart_device).permit(:name, :device_id, :device_type, :description, :building_id)
  end
end
