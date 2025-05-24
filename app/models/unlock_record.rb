class UnlockRecord < ApplicationRecord
  belongs_to :smart_device
  belongs_to :device_user, foreign_key: "user_id", primary_key: "user_id", optional: true

  validates :time, presence: true
  # validates :record_id, uniqueness: true, allow_nil: true

  scope :recent, -> { order(time: :desc) }
  # Scope to get recent records

  # Class method to sync records from Tuya API with pagination and progress tracking
  def self.sync_from_tuya(smart_device, days = 30, &progress_callback)
    return { error: "Device is not a smart lock" } unless smart_device.smart_lock?

    # Get the latest record timestamp for incremental sync
    latest_record = smart_device.unlock_records.order(time: :desc).first

    # Set initial pagination parameters
    page_size = 50
    page_no = 1
    total_records = nil
    total_pages = nil
    fetched_count = 0
    records_synced = 0
    records_skipped = 0
    all_done = false
    job_id = Thread.current[:job_id] # Get job ID from current thread if available

    # Generate a stop check key if job_id is available
    stop_check_key = job_id.present? ? "sync_job_stop:#{job_id}" : nil

    # Prepare options for API call
    options = {
      page_no: page_no,
      page_size: page_size
    }

    # If we have a latest record, use its timestamp for incremental sync
    if latest_record.present?
      start_time = (latest_record.time.to_i * 1000)
      options[:start_time] = start_time
      Rails.logger.info("Starting incremental sync from timestamp: #{Time.at(start_time/1000)}")
    else
      # For first sync, use default time range
      end_time = Time.now.to_i * 1000
      start_time = (Time.now - days.days).to_i * 1000
      options[:start_time] = start_time
      options[:end_time] = end_time
      Rails.logger.info("Starting full sync for the last #{days} days")
    end

    # Collection of all records from all pages before database operations
    all_records_to_process = []

    begin
      # First API call to get the total count before starting pagination
      initial_response = smart_device.get_unlock_records_from_api(options)

      if initial_response[:error].present?
        Rails.logger.error("Error during initial count: #{initial_response[:error]}")
        return { error: initial_response[:error] }
      end

      # Initialize the total count from the first response
      if initial_response[:count].present? && initial_response[:count] > 0
        total_records = initial_response[:count].to_i
        total_pages = (total_records.to_f / page_size).ceil
        Rails.logger.info("Found #{total_records} records to sync across #{total_pages} pages")

        # Report initial progress if a callback is provided
        if block_given?
          progress_callback.call({
            current_page: 0,
            total_pages: total_pages,
            fetched: 0,
            total: total_records,
            synced: 0,
            skipped: 0,
            percent: 0
          })
        end
      end

      # Loop until we've fetched all pages or encountered an error
      while !all_done
        # Check if the sync process was requested to stop
        if stop_check_key.present? && Rails.cache.exist?(stop_check_key)
          Rails.logger.info("Sync was requested to stop. Raising exception to trigger rollback.")
          # Instead of returning, raise an exception to ensure transaction rollback
          raise StandardError, "stop_requested"
        end

        # Make the API call to get the current page of records
        api_response = smart_device.get_unlock_records_from_api(options)

        # Check for errors
        if api_response[:error].present?
          Rails.logger.error("Error during sync: #{api_response[:error]}")
          return {
            error: api_response[:error],
            synced: records_synced,
            skipped: records_skipped,
            total_fetched: fetched_count,
            total_records: total_records
          }
        end

        # Update total counts if needed
        if page_no == 1 && (total_records.nil? || total_records == 0)
          total_records = api_response[:count] || api_response[:records]&.size || 0
          total_pages = (total_records.to_f / page_size).ceil
          Rails.logger.info("Updated count: Found #{total_records} records to sync across #{total_pages} pages")
        end

        # Process records from current page
        current_page_records = api_response[:records] || []
        fetched_count += current_page_records.size

        # Collect records for batch processing later
        all_records_to_process.concat(current_page_records)

        # Calculate accurate progress percentage based on fetched vs total
        percent = total_records && total_records > 0 ?
                  ((fetched_count.to_f / total_records) * 100).round :
                  ((page_no.to_f / (total_pages || 1)) * 100).round

        # Log progress
        Rails.logger.info("Fetched page #{page_no}: #{current_page_records.size} records (#{fetched_count} total, #{percent}%)")

        # Report progress if a callback is provided
        if block_given?
          progress_callback.call({
            current_page: page_no,
            total_pages: total_pages,
            fetched: fetched_count,
            total: total_records,
            synced: 0, # Will be updated after transaction completion
            skipped: 0, # Will be updated after transaction completion
            percent: percent
          })
        end

        # Check if we need to fetch more pages
        if !api_response[:has_more] || current_page_records.empty?
          all_done = true
          Rails.logger.info("All records fetched. Total: #{fetched_count}")
        else
          # Move to next page
          page_no += 1
          options[:page_no] = page_no
          Rails.logger.info("Fetching next page: #{page_no} of #{total_pages}")

          # Small delay to prevent overwhelming the API
          sleep(0.2)
        end
      end

      # Now that we have fetched all records, process them in a single transaction
      result = { synced: 0, skipped: 0 }
      Rails.logger.info("Starting transaction to process #{all_records_to_process.size} records")

      # Final check for stop signal before starting the transaction
      if stop_check_key.present? && Rails.cache.exist?(stop_check_key)
        Rails.logger.info("Stop signal detected before starting transaction. Aborting without committing any changes.")
        return {
          error: "Đồng bộ đã dừng theo yêu cầu",
          synced: 0,
          skipped: 0,
          total_fetched: fetched_count,
          total_records: total_records,
          stopped: true
        }
      end

      begin
        # Process all records in a single transaction
        ActiveRecord::Base.transaction do
          # Process all records
          result = process_records(smart_device, all_records_to_process)

          # Final check for stop signal after processing
          if stop_check_key.present? && Rails.cache.exist?(stop_check_key)
            Rails.logger.info("Stop signal detected after processing. Rolling back transaction.")
            raise StandardError, "stop_requested"
          end
        end

        # Return success result
        {
          synced: result[:synced],
          skipped: result[:skipped],
          total_fetched: fetched_count,
          total_records: total_records
        }
      rescue StandardError => e
        if e.message == "stop_requested"
          # Stop request detected, transaction was rolled back
          Rails.logger.info("Sync stopped as requested. All changes have been rolled back.")
          {
            error: "Đồng bộ đã dừng theo yêu cầu. Đã hoàn tác mọi thay đổi.",
            synced: 0,
            skipped: 0,
            total_fetched: fetched_count,
            total_records: total_records,
            stopped: true
          }
        else
          # Other errors, log and return
          Rails.logger.error("Error during transaction: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          {
            error: e.message,
            synced: 0,
            skipped: 0,
            total_fetched: fetched_count
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
        skipped: 0,
        total_fetched: fetched_count
      }
    end
  end

  # Helper method to process and save a batch of records
  def self.process_records(smart_device, records)
    synced = 0
    skipped = 0
    processed_records = []

    # Check for stop signal before starting processing
    job_id = Thread.current[:job_id]
    if job_id.present? && Rails.cache.exist?("sync_job_stop:#{job_id}")
      Rails.logger.info("Sync stop signal detected before record processing. Will trigger rollback.")
      raise StandardError, "stop_requested"
    end

    # Process each record
    records.each_with_index do |record, index|
      # Check for stop signal more frequently (every 5 records)
      if job_id.present? && index > 0 && index % 5 == 0
        if Rails.cache.exist?("sync_job_stop:#{job_id}")
          Rails.logger.info("Sync stop signal detected during record processing at index #{index}. Will trigger rollback.")
          raise StandardError, "stop_requested"
        end
      end

      # Parse timestamp from the record
      unlock_time = if record[:time].is_a?(String)
        Time.parse(record[:time]) rescue Time.now
      else
        Time.at(record[:time] / 1000) rescue Time.now
      end

      # Check if the record already exists
      existing = UnlockRecord.find_by(smart_device: smart_device, time: unlock_time)

      if existing.nil?
        # Create a new record if it doesn't exist
        new_record = UnlockRecord.create!(
          smart_device: smart_device,
          time: unlock_time,
          user_id: record[:user],
          user_name: record[:unlock_name],
          unlock_method: record[:method],
          success: record[:success] || true,
          raw_data: record[:raw_data] || record
        )
        processed_records << new_record
        synced += 1
      else
        skipped += 1
      end
    end

    # Final check for stop signal before returning
    if job_id.present? && Rails.cache.exist?("sync_job_stop:#{job_id}")
      Rails.logger.info("Sync stop signal detected after record processing. Will trigger rollback.")
      raise StandardError, "stop_requested"
    end

    { synced: synced, skipped: skipped, processed_records: processed_records }
  end
end
