class SyncDeviceUsersJob < ApplicationJob
  queue_as :default
  include ActionView::Helpers::TextHelper

  # This job handles syncing device users in the background
  # and broadcasts progress updates to the view
  def perform(smart_device_id, user_id = nil)
    @smart_device = SmartDevice.find_by(id: smart_device_id)
    return unless @smart_device

    # Get job ID for progress tracking
    job_id = provider_job_id
    cache_key = "sync_job:#{job_id}"
    stop_key = "sync_job_stop:#{job_id}"

    # Xóa bất kỳ yêu cầu dừng nào từ trước
    Rails.cache.delete(stop_key)

    # Store initial progress in cache
    update_progress(cache_key, 0, I18n.t("sync_device_users.starting"), "running", @smart_device.id)

    # Set job_id in current thread for stopping capability
    Thread.current[:job_id] = job_id

    # Start the sync with progress tracking
    begin
      results = sync_device_users_with_progress(@smart_device, cache_key)

      # Handle completion
      if results[:error].present?
        if results[:stopped]
          # Nếu quá trình đồng bộ bị dừng theo yêu cầu người dùng
          message = I18n.t("sync_device_users.stopped",
            synced: pluralize(results[:synced], I18n.t("sync_device_users.user_added")),
            updated: pluralize(results[:updated], I18n.t("sync_device_users.user_updated"))
          )
          # Ghi log rõ ràng về việc dừng
          Rails.logger.info("Sync job stopped: #{message}")

          # Cập nhật trạng thái trong cache
          update_progress(
            cache_key,
            100,
            message,
            "stopped",
            @smart_device.id
          )

          # Phát sóng cập nhật tiến trình
          broadcast_progress_update(
            100,
            message,
            "stopped"
          )

          # Đảm bảo rằng cache vẫn giữ trạng thái này
          Rails.cache.write(cache_key, {
            percent: 100,
            message: message,
            status: "stopped",
            updated_at: Time.now.to_i,
            device_id: @smart_device.id
          }, expires_in: 2.hours)

          # Delete the stop signal now that we're done
          Rails.cache.delete(stop_key)
        else
          # Nếu có lỗi khác
          message = I18n.t("sync_device_users.error", error: results[:error])
          Rails.logger.error("Sync job error: #{message}")

          update_progress(
            cache_key,
            100,
            message,
            "error"
          )
          broadcast_progress_update(100, message, "error")
        end
      else
        update_progress(
          cache_key,
          100,
          I18n.t("sync_device_users.completed",
            synced: pluralize(results[:synced], I18n.t("sync_device_users.user_added")),
            updated: pluralize(results[:updated], I18n.t("sync_device_users.user_updated"))
          ),
          "completed"
        )
        broadcast_progress_update(
          100,
          I18n.t("sync_device_users.completed",
            synced: pluralize(results[:synced], I18n.t("sync_device_users.user_added")),
            updated: pluralize(results[:updated], I18n.t("sync_device_users.user_updated"))
          ),
          "completed"
        )
      end

    rescue => e
      Rails.logger.error("Error in sync job: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      update_progress(cache_key, 100, I18n.t("sync_device_users.error", error: e.message), "error")
      broadcast_progress_update(100, I18n.t("sync_device_users.error", error: e.message), "error")
    end
  end

  private

  # Sync device users with progress tracking
  def sync_device_users_with_progress(smart_device, cache_key)
    return { error: "Device is not a smart lock" } unless smart_device.smart_lock?

    # Fetch all users through API
    api_response = smart_device.get_lock_users_from_api(1, 50)

    if api_response[:error].present?
      return { error: api_response[:error] }
    end

    total_users = api_response[:users].size
    Rails.logger.info("Found #{total_users} users to sync")

    # Report progress at 10%
    update_progress(cache_key, 10, I18n.t("sync_device_users.processing", count: total_users))
    broadcast_progress_update(10, I18n.t("sync_device_users.processing", count: total_users))

    job_id = Thread.current[:job_id]
    stop_key = job_id.present? ? "sync_job_stop:#{job_id}" : nil

    # Check for stop signal before starting
    if stop_key.present? && Rails.cache.exist?(stop_key)
      return {
        error: "Đồng bộ đã dừng theo yêu cầu",
        synced: 0,
        updated: 0,
        stopped: true
      }
    end

    begin
      # Process all users in a transaction for atomic operations
      users_synced = 0
      users_updated = 0

      # Final check for stop signal before starting the transaction
      if stop_key.present? && Rails.cache.exist?(stop_key)
        Rails.logger.info("Stop signal detected before starting transaction. Aborting.")
        return {
          error: "Đồng bộ đã dừng theo yêu cầu",
          synced: 0,
          updated: 0,
          stopped: true
        }
      end

      begin
        # Process all users in a single transaction
        ActiveRecord::Base.transaction do
          if api_response[:users].present?
            api_response[:users].each_with_index do |user, index|
              # Check for stop signal periodically
              if job_id.present? && index > 0 && index % 5 == 0
                if Rails.cache.exist?("sync_job_stop:#{job_id}")
                  Rails.logger.info("Sync stop signal detected during user processing at index #{index}. Will trigger rollback.")
                  raise StandardError, "stop_requested"
                end
              end

              next unless user[:id].present?

              # Update progress every few users
              if index % 5 == 0
                percent = ((index.to_f / total_users) * 80).round + 10  # 10% to 90%
                update_progress(cache_key, percent, I18n.t("sync_device_users.processing_progress",
                  current: index,
                  total: total_users,
                  synced: users_synced,
                  updated: users_updated
                ))
                broadcast_progress_update(percent, I18n.t("sync_device_users.processing_progress",
                  current: index,
                  total: total_users,
                  synced: users_synced,
                  updated: users_updated
                ))
              end

              # Process user with unlock methods if available
              if user[:raw_data] && user[:raw_data]["unlock_methods"].present?
                user[:raw_data]["unlock_methods"].each do |method|
                  device_user = DeviceUser.find_or_initialize_by(
                    smart_device: smart_device,
                    user_id: user[:id],
                    unlock_sn: method["unlock_sn"]
                  )

                  # Update attributes
                  is_new_record = device_user.new_record?
                  device_user.name = user[:name]
                  device_user.status = user[:status] || "active"
                  device_user.avatar_url = user[:avatar_url]
                  device_user.unlock_name = method["unlock_name"]
                  device_user.unlock_sn = method["unlock_sn"]
                  device_user.dp_code = method["dp_code"]
                  device_user.user_type = method["user_type"]

                  # Save raw data
                  device_user.raw_data = {
                    user: user[:raw_data],
                    method: method
                  }

                  device_user.last_active_at = Time.now

                  if device_user.save
                    if is_new_record
                      users_synced += 1
                      Rails.logger.info("Added new device user: #{user[:id]}, method: #{method["unlock_name"]}")
                    else
                      users_updated += 1
                      Rails.logger.info("Updated device user: #{user[:id]}, method: #{method["unlock_name"]}")
                    end
                  end
                end
              else
                # Process regular user without unlock methods
                device_user = DeviceUser.find_or_initialize_by(
                  smart_device: smart_device,
                  user_id: user[:id]
                )

                # Update attributes
                is_new_record = device_user.new_record?
                device_user.name = user[:name]
                device_user.status = user[:status] || "active"
                device_user.avatar_url = user[:avatar_url]
                device_user.raw_data = user[:raw_data] || user
                device_user.last_active_at = Time.now

                if device_user.save
                  if is_new_record
                    users_synced += 1
                    Rails.logger.info("Added new device user: #{user[:id]}")
                  else
                    users_updated += 1
                    Rails.logger.info("Updated device user: #{user[:id]}")
                  end
                end
              end
            end
          end

          # Final check for stop signal after processing
          if stop_key.present? && Rails.cache.exist?(stop_key)
            Rails.logger.info("Stop signal detected after processing. Rolling back transaction.")
            raise StandardError, "stop_requested"
          end
        end

        # Return success result
        {
          synced: users_synced,
          updated: users_updated,
          total: total_users
        }
      rescue StandardError => e
        if e.message == "stop_requested"
          # Stop request detected, transaction was rolled back
          Rails.logger.info("Sync stopped as requested. All changes have been rolled back.")
          {
            error: "Đồng bộ đã dừng theo yêu cầu. Đã hoàn tác mọi thay đổi.",
            synced: 0,
            updated: 0,
            stopped: true
          }
        else
          # Other errors, log and return
          Rails.logger.error("Error during transaction: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          {
            error: e.message,
            synced: 0,
            updated: 0
          }
        end
      end
    rescue => e
      # Handle any other unexpected errors
      Rails.logger.error("Error during sync process: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      {
        error: e.message,
        synced: 0,
        updated: 0
      }
    end
  end

  # Update progress in Redis cache
  def update_progress(cache_key, percent, message, status = "running", device_id = nil)
    Rails.logger.info("Updating progress: #{percent}% - #{message}")

    # Ensure percent is a valid integer
    percent = percent.to_i

    # Store in cache for polling
    Rails.cache.write(
      cache_key,
      {
        percent: percent,
        message: message,
        status: status,
        updated_at: Time.now.to_i,
        device_id: device_id
      },
      expires_in: 2.hours
    )
  end

  # Also try to broadcast via Turbo Streams for real-time updates if available
  def broadcast_progress_update(percent, message, status = "running")
    return unless defined?(Turbo::StreamsChannel)

    channel = "sync_progress_#{@smart_device.id}"
    completed = status == "completed" || status == "error" || status == "stopped"
    success = status == "completed" # Chỉ "completed" mới là thành công
    stopped = status == "stopped"
    stopping = status == "stopping"

    begin
      Turbo::StreamsChannel.broadcast_update_to(
        channel,
        target: "sync_progress_bar",
        partial: "smart_devices/sync_progress",
        locals: {
          percent: percent,
          message: message,
          completed: completed,
          success: success,
          stopped: stopped,
          stopping: stopping,
          status: status
        }
      )
    rescue => e
      Rails.logger.error("Failed to broadcast progress via Turbo: #{e.message}")
    end
  end
end
