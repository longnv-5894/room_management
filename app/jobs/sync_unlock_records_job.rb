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

    # Store initial progress in cache
    update_progress(cache_key, 0, "Đang bắt đầu đồng bộ...")

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
          "Đang đồng bộ trang #{status[:current_page]}/#{status[:total_pages]}: " +
          "#{pluralize(status[:fetched], 'bản ghi')} đã tải, " +
          "#{pluralize(status[:synced], 'bản ghi')} đã lưu"
        else
          "Đang đồng bộ: #{pluralize(status[:fetched], 'bản ghi')} đã tải, " +
          "#{pluralize(status[:synced], 'bản ghi')} đã lưu"
        end

        # Update progress in cache for AJAX polling
        update_progress(cache_key, percent, message)

        # Also attempt to broadcast via Turbo Streams for real-time updates
        broadcast_progress_update(percent, message)
      end

      # Handle completion
      if results[:error].present?
        update_progress(
          cache_key,
          100,
          "Lỗi: #{results[:error]}",
          "error"
        )
      else
        update_progress(
          cache_key,
          100,
          "Hoàn thành: #{pluralize(results[:synced], 'bản ghi')} đã thêm, #{pluralize(results[:skipped], 'bản ghi')} đã bỏ qua.",
          "completed"
        )
      end

    rescue => e
      Rails.logger.error("Error in sync job: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      update_progress(cache_key, 100, "Lỗi: #{e.message}", "error")
    end
  end

  private

  # Update progress in Redis cache
  def update_progress(cache_key, percent, message, status = "running")
    Rails.logger.info("Updating progress: #{percent}% - #{message}")

    Rails.cache.write(
      cache_key,
      {
        percent: percent,
        message: message,
        status: status,
        updated_at: Time.now.to_i
      },
      expires_in: 1.hour
    )
  end

  # Also try to broadcast via Turbo Streams for real-time updates if available
  def broadcast_progress_update(percent, message, completed = false, success = true)
    return unless defined?(Turbo::StreamsChannel)

    channel = "sync_progress_#{@smart_device.id}"

    begin
      Turbo::StreamsChannel.broadcast_update_to(
        channel,
        target: "sync_progress_bar",
        partial: "smart_devices/sync_progress",
        locals: {
          percent: percent,
          message: message,
          completed: completed,
          success: success
        }
      )
    rescue => e
      Rails.logger.error("Failed to broadcast progress via Turbo: #{e.message}")
    end
  end
end
