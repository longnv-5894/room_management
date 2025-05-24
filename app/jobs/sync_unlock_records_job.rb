class SyncUnlockRecordsJob < ApplicationJob
  queue_as :default
  include ActionView::Helpers::TextHelper

  # This job handles syncing unlock records in the background
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
    update_progress(cache_key, 0, I18n.t("sync_unlock_records.starting"), "running", @smart_device.id)

    # Set job_id in current thread for stopping capability
    Thread.current[:job_id] = job_id

    # Start the sync with progress tracking
    begin
      results = UnlockRecord.sync_from_tuya(@smart_device, 30) do |status|
        # Calculate percentage based on the records fetched vs total
        if status[:total] && status[:total] > 0
          percent = ((status[:fetched].to_f / status[:total]) * 100).round
        else
          # If we don't know the total, estimate based on current page
          percent = status[:current_page] ? (status[:current_page] * 10) : 10
          # Cap at 90% until we're done
          percent = [ percent, 90 ].min
        end

        # Create a descriptive message
        message = if status[:total_pages] && status[:total_pages] > 0
          I18n.t("sync_unlock_records.progress_with_pages",
            current_page: status[:current_page],
            total_pages: status[:total_pages],
            fetched: pluralize(status[:fetched], I18n.t("sync_unlock_records.record")),
            synced: pluralize(status[:synced], I18n.t("sync_unlock_records.record_saved"))
          )
        else
          I18n.t("sync_unlock_records.progress_simple",
            fetched: pluralize(status[:fetched], I18n.t("sync_unlock_records.record")),
            synced: pluralize(status[:synced], I18n.t("sync_unlock_records.record_saved"))
          )
        end

        # Update progress in cache for AJAX polling
        update_progress(cache_key, percent, message)

        # Also attempt to broadcast via Turbo Streams for real-time updates
        broadcast_progress_update(percent, message)
      end

      # Handle completion
      if results[:error].present?
        if results[:stopped]
          # Nếu quá trình đồng bộ bị dừng theo yêu cầu người dùng
          message = I18n.t("sync_unlock_records.stopped",
            synced: pluralize(results[:synced], I18n.t("sync_unlock_records.record_added")),
            skipped: pluralize(results[:skipped], I18n.t("sync_unlock_records.record_skipped"))
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
          message = I18n.t("sync_unlock_records.error", error: results[:error])
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
          I18n.t("sync_unlock_records.completed",
            synced: pluralize(results[:synced], I18n.t("sync_unlock_records.record_added")),
            skipped: pluralize(results[:skipped], I18n.t("sync_unlock_records.record_skipped"))
          ),
          "completed"
        )
        broadcast_progress_update(
          100,
          I18n.t("sync_unlock_records.completed",
            synced: pluralize(results[:synced], I18n.t("sync_unlock_records.record_added")),
            skipped: pluralize(results[:skipped], I18n.t("sync_unlock_records.record_skipped"))
          ),
          "completed"
        )
      end

    rescue => e
      Rails.logger.error("Error in sync job: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      update_progress(cache_key, 100, I18n.t("sync_unlock_records.error", error: e.message), "error")
      broadcast_progress_update(100, I18n.t("sync_unlock_records.error", error: e.message), "error")
    end
  end

  private

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
