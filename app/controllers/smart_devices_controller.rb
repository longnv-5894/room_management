class SmartDevicesController < ApplicationController
  before_action :require_login
  before_action :set_smart_device, only: [ :show, :edit, :update, :destroy, :device_info, :device_functions, :device_logs, :unlock_door, :lock_door, :battery_level, :device_unlock_records, :password_list, :add_password, :delete_password, :lock_users, :sync_device_data, :sync_unlock_records, :sync_device_users, :device_unlock_records, :device_users, :link_user_to_tenant, :unlink_user_from_tenant ]
  before_action :set_building, only: [ :index, :new, :create ]

  def index
    if @building
      @smart_devices = @building.smart_devices
    else
      @smart_devices = SmartDevice.all
    end
  end

  def show
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
        flash.now[:alert] = t("smart_devices.alerts.no_devices_found")
      end
      devices
    rescue => e
      Rails.logger.error("Failed to fetch Tuya devices: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n")) if e.backtrace

      if e.message.include?("Thiếu cấu hình Tuya API")
        flash.now[:alert] = t("smart_devices.alerts.missing_api_config")
      elsif e.message.include?("request time is invalid")
        flash.now[:alert] = t("smart_devices.alerts.time_sync_error")
      elsif e.message.include?("token is expired") || e.message.include?("token is invalid")
        flash.now[:alert] = t("smart_devices.alerts.token_expired")
      else
        flash.now[:alert] = t("smart_devices.alerts.cannot_fetch_devices", error: e.message)
      end
      []
    end
  end

  def create
    @smart_device = SmartDevice.new(smart_device_params)
    @smart_device.building = @building if @building && !params[:smart_device][:building_id].present?

    if @smart_device.save
      redirect_to smart_device_path(@smart_device), notice: t("smart_devices.success.created")
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
      redirect_to smart_device_path(@smart_device), notice: t("smart_devices.success.updated")
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
      redirect_to building_path(building), notice: t("smart_devices.success.deleted")
    elsif building.present?
      redirect_to building_smart_devices_path(building), notice: t("smart_devices.success.deleted")
    else
      redirect_to smart_devices_path, notice: t("smart_devices.success.deleted")
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


  def unlock_door
    result = @smart_device.unlock

    respond_to do |format|
      if result[:error].blank?
        format.html { redirect_to @smart_device, notice: t("smart_devices.lock.unlock_success") }
        format.json { render json: { success: true, message: t("smart_devices.lock.unlock_success") } }
      else
        format.html { redirect_to @smart_device, alert: t("smart_devices.lock.unlock_error", error: result[:error]) }
        format.json { render json: { success: false, error: result[:error] }, status: :unprocessable_entity }
      end
    end
  end

  def lock_door
    result = @smart_device.lock

    respond_to do |format|
      if result[:error].blank?
        format.html { redirect_to @smart_device, notice: t("smart_devices.lock.lock_success") }
        format.json { render json: { success: true, message: t("smart_devices.lock.lock_success") } }
      else
        format.html { redirect_to @smart_device, alert: t("smart_devices.lock.lock_error", error: result[:error]) }
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
        format.html { redirect_to password_list_smart_device_path(@smart_device), notice: t("smart_devices.lock.password_added") }
        format.json { render json: { success: true } }
      else
        format.html { redirect_to password_list_smart_device_path(@smart_device), alert: t("smart_devices.lock.password_add_error", error: result[:error]) }
        format.json { render json: { success: false, error: result[:error] }, status: :unprocessable_entity }
      end
    end
  end

  def delete_password
    password_id = params[:password_id]
    result = @smart_device.delete_password(password_id)

    respond_to do |format|
      if result[:success]
        format.html { redirect_to password_list_smart_device_path(@smart_device), notice: t("smart_devices.lock.password_deleted") }
        format.json { render json: { success: true } }
      else
        format.html { redirect_to password_list_smart_device_path(@smart_device), alert: t("smart_devices.lock.password_delete_error", error: result[:error]) }
        format.json { render json: { success: false, error: result[:error] }, status: :unprocessable_entity }
      end
    end
  end

  def lock_users
    page = params[:page].present? ? params[:page].to_i : 1
    page_size = params[:page_size].present? ? params[:page_size].to_i : 20

    # Get users from database by default
    @lock_users = @smart_device.get_lock_users(page, page_size)

    # Only force API fetch if explicitly requested
    if params[:force_api].present?
      # Sync users from API
      DeviceUser.sync_from_tuya(@smart_device)

      # Refresh the data from database
      @lock_users = @smart_device.get_lock_users(page, page_size)
    end

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
        flash.now[:success] = t("smart_devices.alerts.successful_connection_with_offset", offset: time_offset)
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
        flash[:alert] = t("smart_devices.alerts.no_devices_found")
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
            name: device[:name] || t("smart_devices.default.new_device"),
            device_id: device[:id],
            device_type: device[:category] || "unknown"
          )
          new_devices_count += 1
        end
      end

      flash[:notice] = t("smart_devices.sync.success", new_count: new_devices_count, updated_count: updated_devices_count)
    rescue => e
      Rails.logger.error("Failed to sync Tuya devices: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
      flash[:alert] = t("smart_devices.sync.error", error: e.message)
    end

    redirect_to smart_devices_path
  end

  # Đồng bộ dữ liệu từ Tuya API vào cơ sở dữ liệu
  def sync_device_data
    @smart_device = SmartDevice.find(params[:id])
    results = @smart_device.sync_data_from_tuya

    respond_to do |format|
      if results[:error].present?
        format.html { redirect_to @smart_device, alert: t("smart_devices.sync.device_error", error: results[:error]) }
        format.json { render json: { success: false, error: results[:error] }, status: :unprocessable_entity }
      else
        unlock_record_msg = t("smart_devices.sync.records_synced", count: results[:unlock_records][:synced])
        users_msg = t("smart_devices.sync.users_synced", new_count: results[:device_users][:synced], updated_count: results[:device_users][:updated])

        format.html {
          flash[:notice] = t("smart_devices.sync.device_success", unlock_records: unlock_record_msg, users: users_msg)
          redirect_to @smart_device
        }
        format.json { render json: results, status: :ok }
      end
    end
  end

  # Đồng bộ chỉ lịch sử mở khóa từ Tuya API vào cơ sở dữ liệu với theo dõi tiến trình
  def sync_unlock_records
    @smart_device = SmartDevice.find(params[:id])

    respond_to do |format|
      format.html do
        # For HTML requests, we'll redirect to the unlock records page and start a background job
        SyncUnlockRecordsJob.perform_later(@smart_device.id, current_user&.id)

        flash[:notice] = t("smart_devices.sync.records_started")
        redirect_to device_unlock_records_smart_device_path(@smart_device)
      end

      format.json do
        # For JSON requests, start the job and return the job ID for polling
        job = SyncUnlockRecordsJob.perform_later(@smart_device.id, current_user&.id)
        job_id = job.provider_job_id

        # Return the job ID so the client can poll for progress
        render json: {
          success: true,
          job_id: job_id,
          message: "Đã bắt đầu đồng bộ"
        }
      end
    end
  end

  # Endpoint để kiểm tra tiến trình của job đồng bộ
  def job_progress
    job_id = params[:job_id]
    cache_key = "sync_job:#{job_id}"
    job_data = Rails.cache.read(cache_key)

    if job_data
      # Return progress information
      render json: {
        percent: job_data[:percent] || 0,
        message: job_data[:message] || I18n.t("sync_unlock_records.starting"),
        completed: job_data[:status] == "completed" || job_data[:status] == "error" || job_data[:status] == "stopped",
        success: job_data[:status] != "error" && job_data[:status] != "stopped",
        error: job_data[:status] == "error" ? job_data[:message] : nil,
        stopped: job_data[:status] == "stopped",
        status: job_data[:status],
        updated_at: job_data[:updated_at]
      }
    else
      # Job data not found in cache
      render json: {
        error: I18n.t("sync_unlock_records.not_found"),
        completed: true,
        success: false
      }, status: :not_found
    end
  end

  # Đồng bộ chỉ người dùng khóa từ Tuya API vào cơ sở dữ liệu với theo dõi tiến trình
  def sync_device_users
    @smart_device = SmartDevice.find(params[:id])

    respond_to do |format|
      format.html do
        # For HTML requests, we'll redirect to the device users page and start a background job
        SyncDeviceUsersJob.perform_later(@smart_device.id, current_user&.id)

        flash[:notice] = t("smart_devices.sync.users_started")
        redirect_to device_users_smart_device_path(@smart_device)
      end

      format.json do
        # For JSON requests, start the job and return the job ID for polling
        job = SyncDeviceUsersJob.perform_later(@smart_device.id, current_user&.id)
        job_id = job.provider_job_id

        # Return the job ID so the client can poll for progress
        render json: {
          success: true,
          job_id: job_id,
          message: "Đã bắt đầu đồng bộ người dùng"
        }
      end
    end
  end

  # Hiển thị lịch sử mở khóa từ cơ sở dữ liệu
  def device_unlock_records
    @smart_device = SmartDevice.find(params[:id])
    records_query = @smart_device.unlock_records.recent

    # Apply filters if present
    if params[:user_id].present?
      records_query = records_query.where(user_id: params[:user_id])
    end

    if params[:unlock_sn].present? && params[:unlock_sn].to_i > 0
      # Filter by unlock_sn from the raw_data if present
      records_query = records_query.where("(raw_data->'status'->>'value') = ?", params[:unlock_sn].to_s)
    end

    if params[:tenant_id].present?
      # Filter by tenant_id through device_user association
      records_query = records_query.joins("LEFT JOIN device_users ON device_users.user_id = unlock_records.user_id")
                               .where(device_users: { tenant_id: params[:tenant_id] })
    end

    # Apply date range filter if present
    if params[:start_date].present? || params[:end_date].present?
      start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.today.beginning_of_month
      end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.today

      # Convert dates to time with proper beginning and end of day
      start_time = start_date.in_time_zone("Asia/Ho_Chi_Minh").beginning_of_day.utc
      end_time = end_date.in_time_zone("Asia/Ho_Chi_Minh").end_of_day.utc

      records_query = records_query.where("time BETWEEN ? AND ?", start_time, end_time)
    end

    # Calculate successful unlocks count for statistics (before pagination)
    @total_count = records_query.count
    @successful_count = records_query.where(success: true).count

    # Apply will_paginate for pagination
    @per_page = 25
    @unlock_records = records_query.paginate(page: params[:page], per_page: @per_page)

    respond_to do |format|
      format.html do
        # For XHR (AJAX) requests, render without layout
        if request.xhr?
          render :device_unlock_records, layout: false
        end
        # For regular requests, render the full page with layout (default behavior)
      end
      format.json { render json: @unlock_records }
    end
  end

  # Hiển thị danh sách người dùng từ cơ sở dữ liệu
  def device_users
    @smart_device = SmartDevice.find(params[:id])
    @device_users = @smart_device.local_device_users

    respond_to do |format|
      format.html
      format.json { render json: @device_users }
    end
  end

  # Liên kết người dùng thiết bị với tenant
  def link_user_to_tenant
    @device_user = DeviceUser.find(params[:device_user_id])
    @tenant = Tenant.find(params[:tenant_id])

    if @device_user.associate_with_tenant(@tenant)
      redirect_to device_users_smart_device_path(@device_user.smart_device),
                  notice: t("smart_devices.lock_users.user_linked", user: @device_user.name, tenant: @tenant.name)
    else
      redirect_to device_users_smart_device_path(@device_user.smart_device),
                  alert: t("smart_devices.lock_users.user_link_error")
    end
  end

  # Hủy liên kết người dùng thiết bị với tenant
  def unlink_user_from_tenant
    @device_user = DeviceUser.find(params[:device_user_id])

    if @device_user.remove_tenant_association
      redirect_to device_users_smart_device_path(@device_user.smart_device),
                  notice: t("smart_devices.lock_users.user_unlinked", user: @device_user.name)
    else
      redirect_to device_users_smart_device_path(@device_user.smart_device),
                  alert: t("smart_devices.lock_users.user_unlink_error")
    end
  end

  # Dừng job đồng bộ đang chạy
  def stop_sync_job
    job_id = params[:job_id]
    cache_key = "sync_job:#{job_id}"
    job_data = Rails.cache.read(cache_key)
    stop_key = "sync_job_stop:#{job_id}"

    if job_data
      # Ghi log việc dừng
      Rails.logger.info("User requested to stop sync job #{job_id}")

      # Đánh dấu job cần dừng - đặt thời gian hết hạn dài hơn để đảm bảo
      # cờ hiệu dừng tồn tại đủ lâu cho job nhận biết
      Rails.cache.write(stop_key, true, expires_in: 2.hours)

      # Cập nhật trạng thái job thành "stopping" (đang dừng, chưa dừng hẳn)
      job_data[:status] = "stopping"
      job_data[:message] = "Đang dừng đồng bộ, vui lòng đợi... Đang hoàn tác các thay đổi."
      job_data[:updated_at] = Time.now.to_i
      Rails.cache.write(cache_key, job_data, expires_in: 2.hours)

      # Try to broadcast the stopping status via Turbo if available
      begin
        if defined?(Turbo::StreamsChannel) && job_data[:device_id].present?
          channel = "sync_progress_#{job_data[:device_id]}"
          Turbo::StreamsChannel.broadcast_update_to(
            channel,
            target: "sync_progress_bar",
            partial: "smart_devices/sync_progress",
            locals: {
              percent: job_data[:percent],
              message: job_data[:message],
              completed: false,
              success: false,
              stopped: false,
              stopping: true,
              status: "stopping"
            }
          )
        end
      rescue => e
        Rails.logger.error("Failed to broadcast stopping status: #{e.message}")
      end

      render json: {
        success: true,
        message: "Đang dừng đồng bộ, đang hoàn tác những thay đổi"
      }
    else
      render json: {
        error: "Không tìm thấy job đồng bộ",
        success: false
      }, status: :not_found
    end
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
